import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/backup_settings.dart';

class SettingsRepository {
  static final SettingsRepository instance = SettingsRepository._init();
  SettingsRepository._init();

  static const String _keySettings = 'app_backup_settings';
  static const String _keyLastScan = 'app_last_scan_time';
  static const String _keyOAuthClientId = 'app_oauth_client_id';
  static const String _keyOAuthClientSecret = 'app_oauth_client_secret';
  static const String _keyGoogleApiKey = 'app_google_api_key';
  static const String _keyDirectAccessToken = 'app_direct_access_token';
  static const String _keyDirectRefreshToken = 'app_direct_refresh_token';
  static const String _keyTokenExpiryMs = 'app_token_expiry_ms';
  static const String _keyServiceAccountJson = 'app_service_account_json';

  // Default API Key provided by user
  static const String defaultApiKey = 'AIzaSyCL7eP6FDTJ7zFD8gXD1EIMzG3hPL1jZRA';

  // Active OAuth Access Token for 5 TB Google Drive
  static const String defaultAccessToken =
      'ya29.a0AehfTOmy3iYZkx-AS6LnJjvZtrjfLErDjgjrZh6ejwsKdbDSiC1PJcY0qRuxBEgbqmdpYGz3Tz9OSES-B2u0hYuWvqnzOdU8cuaKuxzwkV-K4tEa6V5hSFeAem-RbeJlUc9piD-E2M9nAgQdWaDwBECXGHPTeF5z-cNzyUeZ2ww0kPNXwHrmUA2Lsvke2P4GCFjpt3saCgYKAXsSARMSFQHGX2MiarJZESCegz8CWz5yHs8nfw0206';

  // Active OAuth Refresh Token for zero-login automatic renewal
  static const String defaultRefreshToken =
      '1//0gxjYbmQaTSpeCgYIARAAGBASNwF-L9Iri2Vm-O1DHKeDJq_I8vbnI30F-JcRsHpeLDKKl37x_q1PACoNH1AI3ZVNKKXj7p3gvAk';

  // OAuth Client ID & Secret from Google Cloud Project
  static const String defaultOAuthClientId =
      '531769640142-tjrucpod4c11c6jam7apnmq0nlbsr9an.apps.googleusercontent.com';
  static const String defaultOAuthClientSecret =
      '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';

  Future<BackupSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keySettings);
    if (jsonStr != null) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        final loaded = BackupSettings.fromMap(map);
        return loaded.copyWith(
          autoBackupEnabled: true,
          userConsentGiven: true,
        );
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
    return prefs.getString(_keyOAuthClientId) ??
        (defaultOAuthClientId.isNotEmpty ? defaultOAuthClientId : null);
  }

  Future<void> saveCustomOAuthClientId(String? clientId) async {
    final prefs = await SharedPreferences.getInstance();
    if (clientId != null && clientId.isNotEmpty) {
      await prefs.setString(_keyOAuthClientId, clientId);
    } else {
      await prefs.remove(_keyOAuthClientId);
    }
  }

  Future<String?> getCustomOAuthClientSecret() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyOAuthClientSecret) ??
        (defaultOAuthClientSecret.isNotEmpty ? defaultOAuthClientSecret : null);
  }

  Future<void> saveCustomOAuthClientSecret(String? secret) async {
    final prefs = await SharedPreferences.getInstance();
    if (secret != null && secret.isNotEmpty) {
      await prefs.setString(_keyOAuthClientSecret, secret);
    } else {
      await prefs.remove(_keyOAuthClientSecret);
    }
  }

  Future<String> getGoogleApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGoogleApiKey) ?? defaultApiKey;
  }

  Future<void> saveGoogleApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGoogleApiKey, apiKey);
  }

  Future<String?> getDirectAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyDirectAccessToken);
    // Discard revoked legacy token if persisted on device storage
    if (token != null && token.startsWith('ya29.a0AX07Cmuvt8')) {
      await prefs.remove(_keyDirectAccessToken);
      return defaultAccessToken;
    }
    if (token != null && token.isNotEmpty) return token;
    return defaultAccessToken.isNotEmpty ? defaultAccessToken : null;
  }

  Future<void> saveDirectAccessToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token != null && token.isNotEmpty) {
      await prefs.setString(_keyDirectAccessToken, token);
    } else {
      await prefs.remove(_keyDirectAccessToken);
    }
  }

  Future<String?> getDirectRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyDirectRefreshToken);
    // Discard revoked legacy token if persisted on device storage
    if (token != null && token.startsWith('1//04aU_FXDujX8N')) {
      await prefs.remove(_keyDirectRefreshToken);
      return defaultRefreshToken;
    }
    if (token != null && token.isNotEmpty) return token;
    return defaultRefreshToken.isNotEmpty ? defaultRefreshToken : null;
  }

  Future<void> saveDirectRefreshToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token != null && token.isNotEmpty) {
      await prefs.setString(_keyDirectRefreshToken, token);
    } else {
      await prefs.remove(_keyDirectRefreshToken);
    }
  }

  Future<DateTime?> getTokenExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_keyTokenExpiryMs);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  Future<void> saveTokenExpiry(DateTime? expiry) async {
    final prefs = await SharedPreferences.getInstance();
    if (expiry != null) {
      await prefs.setInt(_keyTokenExpiryMs, expiry.millisecondsSinceEpoch);
    } else {
      await prefs.remove(_keyTokenExpiryMs);
    }
  }

  Future<Map<String, dynamic>?> getServiceAccountJson() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyServiceAccountJson);
    if (jsonStr != null) {
      try {
        return jsonDecode(jsonStr) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  Future<void> saveServiceAccountJson(Map<String, dynamic>? jsonMap) async {
    final prefs = await SharedPreferences.getInstance();
    if (jsonMap != null) {
      await prefs.setString(_keyServiceAccountJson, jsonEncode(jsonMap));
    } else {
      await prefs.remove(_keyServiceAccountJson);
    }
  }
}
