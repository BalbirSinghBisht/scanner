import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/backup_settings.dart';

class DeviceStateService {
  static final DeviceStateService instance = DeviceStateService._init();
  DeviceStateService._init();

  final Connectivity _connectivity = Connectivity();
  final Battery _battery = Battery();

  /// Checks if current network connection meets backup criteria
  Future<bool> isNetworkPermitted(BackupSettings settings) async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();

      // Check for no connection
      if (connectivityResult.contains(ConnectivityResult.none) &&
          connectivityResult.length == 1) {
        return false;
      }

      // If Wi-Fi only is required, verify Wi-Fi or Ethernet is present
      if (settings.wifiOnly) {
        final isWifiOrEthernet = connectivityResult.contains(ConnectivityResult.wifi) ||
            connectivityResult.contains(ConnectivityResult.ethernet);
        return isWifiOrEthernet;
      }

      // If Wi-Fi only is disabled, mobile data or any active connection is allowed
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
