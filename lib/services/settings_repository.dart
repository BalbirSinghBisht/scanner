import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/backup_settings.dart';

class SettingsRepository {
  static final SettingsRepository instance = SettingsRepository._init();
  SettingsRepository._init();

  static const String _keySettings = 'app_backup_settings';
  static const String _keyLastScan = 'app_last_scan_time';
  static const String _keyOAuthClientId = 'app_oauth_client_id';

  Future<BackupSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keySettings);
    if (jsonStr != null) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return BackupSettings.fromMap(map);
      } catch (_) {}
    }
    return const BackupSettings();
  }

  Future<void> saveSettings(BackupSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(settings.toMap());
    await prefs.setString(_keySettings, jsonStr);
  }

  Future<DateTime?> getLastScanTime() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_keyLastScan);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  Future<void> saveLastScanTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastScan, time.millisecondsSinceEpoch);
  }

  Future<String?> getCustomOAuthClientId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyOAuthClientId);
  }

  Future<void> saveCustomOAuthClientId(String? clientId) async {
    final prefs = await SharedPreferences.getInstance();
    if (clientId != null && clientId.isNotEmpty) {
      await prefs.setString(_keyOAuthClientId, clientId);
    } else {
      await prefs.remove(_keyOAuthClientId);
    }
  }
}
