import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'auth_service.dart';
import 'backup_sync_service.dart';
import 'media_scanner_service.dart';
import 'settings_repository.dart';

ServiceInstance? _activeBackgroundServiceInstance;

@pragma('vm:entry-point')
void onStartBackgroundService(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  _activeBackgroundServiceInstance = service;

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
    await service.setAutoStartOnBootMode(true);
    service.setForegroundNotificationInfo(
      title: 'Gallery',
      content: 'Gallery running',
    );

    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    service.on('triggerSync').listen((event) {
      debugPrint('[BackgroundSync] 10-minute silent alarm event received! Running backup cycle now...');
      _runBackgroundSyncCycle(service);
    });
  }

  // Initial check immediately after startup
  Future.delayed(const Duration(seconds: 2), () {
    _runBackgroundSyncCycle(service);
  });

  // Instant trigger when network reconnects after being offline
  Connectivity().onConnectivityChanged.listen((results) {
    final hasConnection = results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);
    if (hasConnection) {
      debugPrint('[BackgroundSync] Network connected detected. Triggering immediate sync cycle...');
      _runBackgroundSyncCycle(service);
    }
  });

  // Fast background check every 15 seconds to catch newly downloaded/saved media immediately and sync pending items
  Timer.periodic(const Duration(seconds: 15), (timer) async {
    try {
      await _runBackgroundSyncCycle(service);
    } catch (e) {
      debugPrint('[BackgroundSync] Periodic cycle caught error: $e');
    }
  });
}

bool _isBackgroundCycleRunning = false;
bool _hasPendingNewMediaTrigger = false;

Future<void> _runBackgroundSyncCycle([ServiceInstance? service]) async {
  if (_isBackgroundCycleRunning) {
    _hasPendingNewMediaTrigger = true;
    // Fast opportunistic scan so newly captured photo/video is in DB immediately
    try {
      await MediaScannerService.instance.scanDirectDirectories();
      final lastScan = await SettingsRepository.instance.getLastScanTime();
      await MediaScannerService.instance.scanMedia(
        forceFullScan: false,
        scanSince: lastScan,
        isBackground: true,
      );
      await SettingsRepository.instance.saveLastScanTime(DateTime.now());
      debugPrint('[BackgroundSync] Immediate scan captured new media while upload running.');
    } catch (_) {}
    return;
  }
  _isBackgroundCycleRunning = true;
  _hasPendingNewMediaTrigger = false;
  final svc = service ?? _activeBackgroundServiceInstance;

  try {
    do {
      _hasPendingNewMediaTrigger = false;
      final settingsRepo = SettingsRepository.instance;
      final settings = await settingsRepo.loadSettings();
      if (settings.isPaused) break;

      if (BackupSyncService.instance.hasAuthError) {
        debugPrint('[BackgroundSync] Auth renewal needed. Attempting background session recovery...');
        final recovered = await AuthService.instance.refreshActiveSession();
        if (recovered) {
          BackupSyncService.instance.clearAuthError();
          debugPrint('[BackgroundSync] Session successfully refreshed in background.');
        } else {
          debugPrint('[BackgroundSync] Auth still awaiting valid token. Will retry on next cycle.');
          break;
        }
      }

      if (svc is AndroidServiceInstance) {
        svc.setForegroundNotificationInfo(
          title: 'Gallery',
          content: 'Gallery running',
        );
      }

      // Acquire native WakeLock during active sync so CPU doesn't sleep while uploading
      if (Platform.isAndroid) {
        try {
          const platform = MethodChannel('com.mediabackup.scanner/device_settings');
          await platform.invokeMethod('acquireWakeLock');
        } catch (_) {}
      }

      // 1. Direct directory scan so any downloaded or camera media is captured even if MediaStore hasn't indexed
      await MediaScannerService.instance.scanDirectDirectories();

      // 2. Incremental media library scan
      final lastScan = await settingsRepo.getLastScanTime();
      await MediaScannerService.instance.scanMedia(
        forceFullScan: false,
        scanSince: lastScan,
        isBackground: true,
      );

      await settingsRepo.saveLastScanTime(DateTime.now());

      // 3. Automatically trigger upload of any pending items to Google Drive
      // (claimNextPendingUpload prioritizes newest media created_at DESC first!)
      await BackupSyncService.instance.startSync(settings: settings);
    } while (_hasPendingNewMediaTrigger);
  } catch (e) {
    debugPrint('Background sync cycle error: $e');
  } finally {
    if (Platform.isAndroid) {
      try {
        const platform = MethodChannel('com.mediabackup.scanner/device_settings');
        await platform.invokeMethod('releaseWakeLock');
      } catch (_) {}
    }
    _isBackgroundCycleRunning = false;
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  _activeBackgroundServiceInstance = service;
  try {
    await _runBackgroundSyncCycle(service);
  } catch (e) {
    debugPrint('iOS background sync cycle error: $e');
  }
  return true;
}

class BackgroundSyncManager {
  static final BackgroundSyncManager instance = BackgroundSyncManager._init();
  BackgroundSyncManager._init();

  /// Initializes the persistent background service (auto-starts on boot, runs continuously)
  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Create high reliability notification channel for Android Foreground Service
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'media_backup_service_channel',
      'Gallery',
      description: 'Gallery service',
      importance: Importance.defaultImportance,
      showBadge: false,
      playSound: false,
      enableVibration: false,
    );

    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStartBackgroundService,
        autoStart: false,
        isForegroundMode: true,
        autoStartOnBoot: true,
        notificationChannelId: 'media_backup_service_channel',
        initialNotificationTitle: 'Gallery',
        initialNotificationContent: 'Gallery running',
        foregroundServiceNotificationId: 991,
        foregroundServiceTypes: [
          AndroidForegroundType.dataSync,
        ],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStartBackgroundService,
        onBackground: onIosBackground,
      ),
    );

    try {
      final isRunning = await service.isRunning();
      if (!isRunning) {
        await service.startService();
      }
    } catch (e) {
      debugPrint('[BackgroundSync] startService notice: $e');
    }

    // Activate Google Photos / OneDrive style native watchdog, wake alarm, and CPU keep-alive
    if (Platform.isAndroid) {
      try {
        const platform = MethodChannel('com.mediabackup.scanner/device_settings');
        await platform.invokeMethod('startWatchdog');
        await platform.invokeMethod('startContinuousKeepAlive');
        debugPrint('[BackgroundSync] Native Android watchdog, MediaStore observer & continuous CPU keep-alive activated.');
      } catch (e) {
        debugPrint('[BackgroundSync] Watchdog init notice: $e');
      }
    }

    // On iOS, activate native audio keep-alive to prevent suspension when device is locked & offline
    if (Platform.isIOS) {
      try {
        const platform = MethodChannel('com.mediabackup.scanner/device_settings');
        await platform.invokeMethod('startBackgroundKeepAlive');
        debugPrint('[BackgroundSync] Native iOS background keep-alive activated.');
      } catch (e) {
        debugPrint('[BackgroundSync] iOS keep-alive notice: $e');
      }
    }
  }
}
