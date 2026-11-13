import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceSettingsHelper {
  static const MethodChannel _channel =
      MethodChannel('com.mediabackup.scanner/device_settings');

  static const String _keyAutostartConfigured = 'oem_autostart_configured_v1';

  /// Checks if OEM autostart is active on device
  static Future<bool> isAutostartConfigured() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('isAutostartEnabled');
      if (res != null) return res;
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyAutostartConfigured) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Sets whether OEM autostart has been configured
  static Future<void> setAutostartConfigured(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutostartConfigured, value);
    } catch (_) {}
  }

  /// Checks if all essential background permissions (Battery & OEM Autostart) are configured
  static Future<bool> areAllRequiredPermissionsGranted() async {
    if (!Platform.isAndroid) return true;
    try {
      final isBatteryIgnored = await isIgnoringBatteryOptimizations();
      if (!isBatteryIgnored) return false;

      final isOEM = await isStrictOEMDevice();
      if (isOEM) {
        final configured = await isAutostartConfigured();
        if (!configured) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Checks if current device is a strict OEM (Realme, Xiaomi, Redmi, POCO, Oppo, OnePlus, Vivo, iQOO, Huawei)
  static Future<bool> isStrictOEMDevice() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isStrictOEMDevice');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks if current device is Xiaomi / Redmi / POCO
  static Future<bool> isXiaomiDevice() async {
    return await isStrictOEMDevice();
  }

  /// Opens Autostart settings directly for Realme, Xiaomi, Oppo, Vivo (falls back to App Info)
  static Future<bool> openAutostartSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('openAutostartSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openXiaomiAutostart() async {
    return await openAutostartSettings();
  }

  /// Checks if All Files Access (MANAGE_EXTERNAL_STORAGE) is granted on Android 11+
  static Future<bool> isAllFilesAccessGranted() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('isAllFilesAccessGranted');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Prompts or opens the All Files Access settings page on Android 11+
  static Future<bool> requestAllFilesAccess() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('requestAllFilesAccess');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens Xiaomi HyperOS / MIUI Battery Saver configuration (PowerKeeper)
  static Future<bool> openXiaomiBatterySaver() async {
    if (!Platform.isAndroid) return false;
    try {
      final res =
          await _channel.invokeMethod<bool>('openXiaomiBatterySaverSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Native media file deletion bypassing Scoped Storage limitations
  static Future<bool> deleteMediaFileNative(String? path, String id) async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('deleteMediaFile', {
        'path': path,
        'id': id,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Shares a local media file via native share sheet (Android & iOS)
  static Future<bool> shareMediaFile(String filePath, String mimeType) async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      final res = await _channel.invokeMethod<bool>('shareFile', {
        'path': filePath,
        'mimeType': mimeType,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Shares multiple local media files via native share sheet (Android & iOS)
  static Future<bool> shareMultipleMediaFiles(List<String> filePaths, {String mimeType = '*/*'}) async {
    if ((!Platform.isAndroid && !Platform.isIOS) || filePaths.isEmpty) return false;
    try {
      final res = await _channel.invokeMethod<bool>('shareMultipleFiles', {
        'paths': filePaths,
        'mimeType': mimeType,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the App Info details page (Android App Info / iOS Settings)
  static Future<bool> openAppInfoSettings() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      final res = await _channel.invokeMethod<bool>('openAppInfoSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks if the app is already exempt from battery optimizations
  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the native Android dialog requesting exemption from battery optimizations
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system Battery Optimization management settings page
  static Future<bool> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('openBatteryOptimizationSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Gets the device manufacturer name (e.g. samsung, xiaomi, google, oneplus, etc.)
  static Future<String> getDeviceManufacturer() async {
    if (!Platform.isAndroid) return 'Apple';
    try {
      final res = await _channel.invokeMethod<String>('getDeviceManufacturer');
      return res ?? 'Android';
    } catch (_) {
      return 'Android';
    }
  }

  /// Gets the device brand name
  static Future<String> getDeviceBrand() async {
    if (!Platform.isAndroid) return 'Apple';
    try {
      final res = await _channel.invokeMethod<String>('getDeviceBrand');
      return res ?? 'Android';
    } catch (_) {
      return 'Android';
    }
  }

  /// Returns clear, manufacturer-specific steps to disable the 15-minute background killer
  static List<String> getOEMGuidanceTips(String manufacturer) {
    final m = manufacturer.toLowerCase();
    if (m.contains('samsung')) {
      return [
        'Set Battery to "Unrestricted" in App Info > Battery.',
        'In Settings > Device Care > Battery > Background usage limits, ensure Gallery is NOT in "Sleeping apps" or "Deep sleeping apps".',
        'Add Gallery to "Never sleeping apps" for guaranteed 24/7 background sync.',
      ];
    } else if (m.contains('xiaomi') || m.contains('redmi') || m.contains('poco')) {
      return [
        'Set Battery Saver to "No restrictions" (by default MIUI kills apps after 15 min).',
        'Turn ON "Autostart" in App Permissions.',
        'Allow "Start in background" in Security settings.',
      ];
    } else if (m.contains('oppo') || m.contains('realme') || m.contains('oneplus')) {
      return [
        'In App Battery Management, enable "Allow background activity".',
        'Enable "Auto-launch" and "Secondary launch".',
        'In Battery > More settings > Optimize battery use, select "Don\'t optimize".',
      ];
    } else if (m.contains('vivo') || m.contains('iqoo')) {
      return [
        'In Settings > Battery > Background power consumption, enable "High background power consumption".',
        'In Permission Manager, turn ON "Autostart".',
      ];
    } else if (m.contains('huawei') || m.contains('honor')) {
      return [
        'In Settings > Battery > App Launch, set Gallery to "Manage manually".',
        'Enable "Auto-launch", "Secondary launch", and "Run in background".',
      ];
    } else {
      return [
        'In App Info > Battery, select "Unrestricted" (preventing the 15-minute Doze kill).',
        'Allow background data usage and unrestricted network access.',
      ];
    }
  }

  /// Checks whether system notification permission is granted
  static Future<bool> isNotificationPermissionGranted() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('areNotificationsEnabled');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Requests notification permission on Android 13+ and iOS (essential for continuous background auto-sync)
  static Future<bool> requestNotificationPermission() async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      if (Platform.isAndroid) {
        final android = plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await android?.requestNotificationsPermission();
        return granted ?? false;
      } else if (Platform.isIOS) {
        final ios = plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final granted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Automatically opens the Autostart settings once on first launch for Realme, Xiaomi, and other strict OEMs
  static Future<void> checkAndOpenXiaomiAutostartOnFirstLaunch() async {
    // Disabled: User only wants standard background permission prompt, not OEM autostart redirects
    return;
  }

  /// Starts native AlarmManager watchdog and MediaStore content observer (Google Photos & OneDrive architecture)
  static Future<void> startWatchdog() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startWatchdog');
    } catch (_) {}
  }

  /// Acquires native CPU WakeLock during active upload batches
  static Future<void> acquireSyncWakeLock() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('acquireWakeLock');
    } catch (_) {}
  }

  /// Releases native CPU WakeLock when upload cycle is complete
  static Future<void> releaseSyncWakeLock() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('releaseWakeLock');
    } catch (_) {}
  }

  /// Schedules an unkillable silent alarm clock wakeup (uses Android Alarm Clock hardware RTC, but 100% silent with no sound or vibration)
  static Future<void> scheduleSilentAlarm({DateTime? at}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('scheduleSilentAlarm', {
        if (at != null) 'triggerAtMillis': at.millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  /// Extracts hardware-accelerated video thumbnail bytes via native platform decoder
  static Future<Uint8List?> getVideoThumbnail(String path, {int width = 360, int height = 360}) async {
    try {
      final res = await _channel.invokeMethod<Uint8List>('getVideoThumbnail', {
        'path': path,
        'width': width,
        'height': height,
      });
      return res;
    } catch (_) {
      return null;
    }
  }

  /// Triggers Android OS media scanner so the newly created/moved file is indexed in system MediaStore and visible in File Manager
  static Future<void> notifyMediaScanner(String filePath, [String? mimeType]) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('scanMediaFile', {
        'path': filePath,
        'mimeType': mimeType,
      });
    } catch (_) {}
  }
}
