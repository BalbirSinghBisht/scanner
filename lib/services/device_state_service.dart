import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/backup_settings.dart';

class DeviceStateService {
  static final DeviceStateService instance = DeviceStateService._init();
  DeviceStateService._init();

  final Connectivity _connectivity = Connectivity();
  final Battery _battery = Battery();
  String? _cachedDeviceFolderName;

  /// Returns a clean root folder name based on device model (e.g. Google_Pixel_7 or Samsung_SM-S911B)
  Future<String> getDeviceBackupFolderName() async {
    if (_cachedDeviceFolderName != null && _cachedDeviceFolderName!.isNotEmpty) {
      return _cachedDeviceFolderName!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final persisted = prefs.getString('persisted_device_folder_name');
      if (persisted != null && persisted.isNotEmpty) {
        _cachedDeviceFolderName = persisted;
        return persisted;
      }

      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final brand = androidInfo.brand.trim();
        final model = androidInfo.model.trim();
        final cleanBrand = brand.replaceAll(RegExp(r'[^\w\-]'), '_');
        final cleanModel = model.replaceAll(RegExp(r'[^\w\-]'), '_');
        if (cleanModel.toLowerCase().contains(cleanBrand.toLowerCase())) {
          _cachedDeviceFolderName = cleanModel;
        } else {
          _cachedDeviceFolderName = '${cleanBrand}_$cleanModel';
        }
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _cachedDeviceFolderName =
            iosInfo.name.replaceAll(RegExp(r'[^\w\-]'), '_');
      }

      _cachedDeviceFolderName ??= 'Phone_Device';
      if (_cachedDeviceFolderName!.isEmpty) {
        _cachedDeviceFolderName = 'Phone_Device';
      }

      await prefs.setString('persisted_device_folder_name', _cachedDeviceFolderName!);
      return _cachedDeviceFolderName!;
    } catch (_) {
      return _cachedDeviceFolderName ?? 'Phone_Device';
    }
  }

  /// Checks if current network connection meets backup criteria (supports both Wi-Fi and mobile data)
  Future<bool> isNetworkPermitted(BackupSettings settings) async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();

      // Check for completely disconnected state
      if (connectivityResult.contains(ConnectivityResult.none) &&
          connectivityResult.length == 1) {
        return false;
      }

      // Both Mobile Data (4G/5G/LTE) and Wi-Fi are fully supported
      return !connectivityResult.contains(ConnectivityResult.none);
    } catch (_) {
      // Default to true on platforms where connectivity plugin isn't supported
      return true;
    }
  }

  /// Checks if battery level & charging state satisfy the user backup settings
  Future<bool> isBatteryPermitted(BackupSettings settings) async {
    try {
      final batteryState = await _battery.batteryState;
      final isCharging = batteryState == BatteryState.charging ||
          batteryState == BatteryState.full;

      if (settings.chargingOnly && !isCharging) {
        return false;
      }

      final batteryLevel = await _battery.batteryLevel;
      if (batteryLevel < settings.minBatteryThreshold && !isCharging) {
        return false;
      }

      return true;
    } catch (_) {
      // Default to permitted on simulator/desktop without battery sensor
      return true;
    }
  }

  Future<int> getBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (_) {
      return 100;
    }
  }

  Future<bool> isCharging() async {
    try {
      final state = await _battery.batteryState;
      return state == BatteryState.charging || state == BatteryState.full;
    } catch (_) {
      return false;
    }
  }

  Future<List<ConnectivityResult>> getCurrentConnectivity() async {
    try {
      return await _connectivity.checkConnectivity();
    } catch (_) {
      return [ConnectivityResult.wifi];
    }
  }
}
