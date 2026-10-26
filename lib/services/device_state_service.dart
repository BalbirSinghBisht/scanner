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
        final model = iosInfo.utsname.machine.trim();
        final name = iosInfo.name.trim();
        final cleanName = name.isNotEmpty && name.toLowerCase() != 'iphone' && name.toLowerCase() != 'ipad'
            ? name
            : 'iOS_${model.isNotEmpty ? model : "Device"}';
        _cachedDeviceFolderName = cleanName.replaceAll(RegExp(r'[^\w\-]'), '_');
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
    if (settings.localOnlyMode) return true;
    try {
      final connectivityResult = await _connectivity.checkConnectivity();

      // Check for completely disconnected state
      if (connectivityResult.isEmpty ||
          (connectivityResult.contains(ConnectivityResult.none) &&
              connectivityResult.length == 1)) {
        return false;
      }

      // If user specified wifiOnly in settings, ensure Wi-Fi is active
      if (settings.wifiOnly && !connectivityResult.contains(ConnectivityResult.wifi)) {
        return false;
      }

      // Quick active internet reachability check
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 3));
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    } catch (_) {
      return false;
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
      if (batteryLevel < 5 && !isCharging) {
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
