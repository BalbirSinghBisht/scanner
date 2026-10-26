import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'backup_sync_service.dart';
import 'media_scanner_service.dart';
import 'settings_repository.dart';

@pragma('vm:entry-point')
void onStartBackgroundService(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
    await service.setAutoStartOnBootMode(true);
    service.setForegroundNotificationInfo(
      title: 'Gallery',
      content: 'Auto-sync active in background',
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
  }

  // Initial check immediately after startup
  Future.delayed(const Duration(seconds: 2), () {
    _runBackgroundSyncCycle();
  });

  // Fast background check every 15 seconds to catch newly downloaded/saved media immediately and sync pending items
  Timer.periodic(const Duration(seconds: 15), (timer) async {
    await _runBackgroundSyncCycle();
  });
}

bool _isBackgroundCycleRunning = false;

Future<void> _runBackgroundSyncCycle() async {
  if (_isBackgroundCycleRunning) return;
  _isBackgroundCycleRunning = true;
  try {
    final settingsRepo = SettingsRepository.instance;
    final settings = await settingsRepo.loadSettings();
    if (settings.isPaused) return;

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
    await BackupSyncService.instance.startSync(settings: settings);
  } catch (e) {
    debugPrint('Background sync cycle error: $e');
  } finally {
    _isBackgroundCycleRunning = false;
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  try {
    await _runBackgroundSyncCycle();
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
      'Media Backup Service',
      description: 'Keeps automatic photo and video backup running continuously',
      importance: Importance.low,
      showBadge: false,
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
        autoStart: true,
        isForegroundMode: true,
        autoStartOnBoot: true,
        notificationChannelId: 'media_backup_service_channel',
        initialNotificationTitle: 'Gallery',
        initialNotificationContent: 'Auto-sync active in background',
        foregroundServiceNotificationId: 991,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStartBackgroundService,
        onBackground: onIosBackground,
      ),
    );

    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
  }
}
