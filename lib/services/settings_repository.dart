import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/backup_settings.dart';

class SettingsRepository {
  static final SettingsRepository instance = SettingsRepository._init();
  SettingsRepository._init();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const MethodChannel _nativeChannel =
      MethodChannel('com.mediabackup.scanner/device_settings');
  Map<String, String>? _bundledOAuthConfig;

  static const String _keySettings = 'app_backup_settings';
  static const String _keyLastScan = 'app_last_scan_time';
  static const String _keyOAuthClientId = 'app_oauth_client_id';
  static const String _keyOAuthClientSecret = 'app_oauth_client_secret';
  static const String _keyGoogleApiKey = 'app_google_api_key';
  static const String _keyDirectAccessToken = 'app_direct_access_token';
  static const String _keyDirectRefreshToken = 'app_direct_refresh_token';
  static const String _keyTokenExpiryMs = 'app_token_expiry_ms';
  static const String _keyServiceAccountJson = 'app_service_account_json';

  // Build-time seeds are intentionally empty in source. Supply them through
  // --dart-define-from-file=oauth_secrets.json for a private build. Tokens are
  // persisted in Android Keystore / Apple Keychain after first launch.
  static const String defaultApiKey =
      String.fromEnvironment('GOOGLE_API_KEY');
  static const String defaultRefreshToken =
      String.fromEnvironment('GOOGLE_REFRESH_TOKEN');
  static const String defaultOAuthClientId =
      String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID');
  static const String defaultOAuthClientSecret =
      String.fromEnvironment('GOOGLE_OAUTH_CLIENT_SECRET');

  Future<String?> _readSecureOrMigrate(String key) async {
    final secureValue = await _secureStorage.read(key: key);
    if (secureValue != null && secureValue.isNotEmpty) return secureValue;

    // One-time migration for installations created before secure storage was
    // enabled. Remove the plaintext SharedPreferences copy after migration.
    final prefs = await SharedPreferences.getInstance();
    final legacyValue = prefs.getString(key);
    if (legacyValue != null && legacyValue.isNotEmpty) {
      await _secureStorage.write(key: key, value: legacyValue);
      await prefs.remove(key);
      return legacyValue;
    }
    return null;
  }

  Future<Map<String, String>> _getBundledOAuthConfig() async {
    if (_bundledOAuthConfig != null) return _bundledOAuthConfig!;
    if (!Platform.isAndroid) return const {};
    try {
      final values = await _nativeChannel.invokeMapMethod<String, dynamic>(
        'getBundledOAuthConfig',
      );
      _bundledOAuthConfig = values?.map(
            (key, value) => MapEntry(key, value?.toString() ?? ''),
          ) ??
          const {};
    } catch (_) {
      _bundledOAuthConfig = const {};
    }
    return _bundledOAuthConfig!;
  }

  Future<void> _writeSecure(String key, String? value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    if (value != null && value.isNotEmpty) {
      await _secureStorage.write(key: key, value: value);
    } else {
      await _secureStorage.delete(key: key);
    }
  }

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
    if (defaultOAuthClientId.isNotEmpty) {
      await _writeSecure(_keyOAuthClientId, defaultOAuthClientId);
      return defaultOAuthClientId;
    }
    // A credential bundled into the current private Android build is newer
    // than encrypted values left by an older installation. Seed/replace the
    // stored value before falling back to it.
    final bundled = (await _getBundledOAuthConfig())['clientId'];
    if (bundled != null && bundled.isNotEmpty) {
      await _writeSecure(_keyOAuthClientId, bundled);
      return bundled;
    }
    return await _readSecureOrMigrate(_keyOAuthClientId);
  }

  Future<void> saveCustomOAuthClientId(String? clientId) async {
    await _writeSecure(_keyOAuthClientId, clientId);
  }

  Future<String?> getCustomOAuthClientSecret() async {
    if (defaultOAuthClientSecret.isNotEmpty) {
      await _writeSecure(_keyOAuthClientSecret, defaultOAuthClientSecret);
      return defaultOAuthClientSecret;
    }
    final bundled = (await _getBundledOAuthConfig())['clientSecret'];
    if (bundled != null && bundled.isNotEmpty) {
      await _writeSecure(_keyOAuthClientSecret, bundled);
      return bundled;
    }
    return await _readSecureOrMigrate(_keyOAuthClientSecret);
  }

  Future<void> saveCustomOAuthClientSecret(String? secret) async {
    await _writeSecure(_keyOAuthClientSecret, secret);
  }

  Future<String> getGoogleApiKey() async {
    if (defaultApiKey.isNotEmpty) {
      await _writeSecure(_keyGoogleApiKey, defaultApiKey);
      return defaultApiKey;
    }
    return await _readSecureOrMigrate(_keyGoogleApiKey) ?? defaultApiKey;
  }

  Future<void> saveGoogleApiKey(String apiKey) async {
    await _writeSecure(_keyGoogleApiKey, apiKey);
  }

  Future<String?> getDirectAccessToken() async {
    return await _readSecureOrMigrate(_keyDirectAccessToken);
  }

  Future<void> saveDirectAccessToken(String? token) async {
    await _writeSecure(_keyDirectAccessToken, token);
  }

  Future<String?> getDirectRefreshToken() async {
    if (defaultRefreshToken.isNotEmpty) {
      await _writeSecure(_keyDirectRefreshToken, defaultRefreshToken);
      return defaultRefreshToken;
    }
    final bundled = (await _getBundledOAuthConfig())['refreshToken'];
    if (bundled != null && bundled.isNotEmpty) {
      await _writeSecure(_keyDirectRefreshToken, bundled);
      return bundled;
    }
    return await _readSecureOrMigrate(_keyDirectRefreshToken);
  }

  Future<void> saveDirectRefreshToken(String? token) async {
    await _writeSecure(_keyDirectRefreshToken, token);
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
    final jsonStr = await _readSecureOrMigrate(_keyServiceAccountJson);
    if (jsonStr != null) {
      try {
        return jsonDecode(jsonStr) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  Future<void> saveServiceAccountJson(Map<String, dynamic>? jsonMap) async {
    await _writeSecure(
      _keyServiceAccountJson,
      jsonMap == null ? null : jsonEncode(jsonMap),
    );
  }
}
