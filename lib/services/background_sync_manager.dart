import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:photo_manager/photo_manager.dart';
import 'backup_sync_service.dart';
import 'media_scanner_service.dart';
import 'settings_repository.dart';

@pragma('vm:entry-point')
void onStartBackgroundService(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
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

  // Delay initial background check to allow foreground UI to complete startup cleanly
  Future.delayed(const Duration(seconds: 30), () {
    _runBackgroundSyncCycle();
  });

  // Listen to photo library changes in real-time in the background
  try {
    PhotoManager.addChangeCallback((call) async {
      debugPrint('Background photo change detected: ${call.method}. Syncing...');
      await _runBackgroundSyncCycle();
    });
    PhotoManager.startChangeNotify();
  } catch (e) {
    debugPrint('Background change notify error: $e');
  }

  // Periodic background check every 10 minutes to auto-capture any new media and upload
  Timer.periodic(const Duration(minutes: 10), (timer) async {
    await _runBackgroundSyncCycle();
  });
}

Future<void> _runBackgroundSyncCycle() async {
  try {
    final settingsRepo = SettingsRepository.instance;
    final settings = await settingsRepo.loadSettings();
    if (settings.isPaused) return;

    // Check media permission
    final perm = await MediaScannerService.instance.requestPermission();
    if (perm != PermissionState.authorized && perm != PermissionState.limited) {
      return;
    }

    // Auto-scan new photos/videos since last scan time
    final lastScan = await settingsRepo.getLastScanTime();
    await MediaScannerService.instance.scanMedia(
      forceFullScan: false,
      scanSince: lastScan,
    );
    await settingsRepo.saveLastScanTime(DateTime.now());

    // Automatically trigger upload of any pending items to Google Drive
    await BackupSyncService.instance.startSync(settings: settings);
  } catch (e) {
    debugPrint('Background sync cycle error: $e');
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
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
        initialNotificationContent: 'Backing up photos & videos',
        foregroundServiceNotificationId: 991,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStartBackgroundService,
        onBackground: onIosBackground,
      ),
    );
  }
}
