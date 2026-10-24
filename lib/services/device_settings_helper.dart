import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceSettingsHelper {
  static const MethodChannel _channel =
      MethodChannel('com.mediabackup.scanner/device_settings');

  static const String _keyAutostartPrompted = 'oem_autostart_prompted_v2';

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

  /// Shares a local media file via native Android share sheet
  static Future<bool> shareMediaFile(String filePath, String mimeType) async {
    if (!Platform.isAndroid) return false;
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

  /// Opens the App Info details page
  static Future<bool> openAppInfoSettings() async {
    if (!Platform.isAndroid) return false;
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

  /// Requests notification permission on Android 13+ (essential for continuous background auto-sync)
  static Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Automatically opens the Autostart settings once on first launch for Realme, Xiaomi, and other strict OEMs
  static Future<void> checkAndOpenXiaomiAutostartOnFirstLaunch() async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyPrompted = prefs.getBool(_keyAutostartPrompted) ?? false;
      if (alreadyPrompted) return;

      final isOEM = await isStrictOEMDevice();
      if (!isOEM) {
        await prefs.setBool(_keyAutostartPrompted, true);
        return;
      }

      // Mark as prompted so it only redirects once on first launch
      await prefs.setBool(_keyAutostartPrompted, true);

      // Brief delay to allow initial media permission dialog to settle
      await Future.delayed(const Duration(milliseconds: 1200));

      await openAutostartSettings();
    } catch (_) {}
  }
}
