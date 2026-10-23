import 'package:flutter/material.dart';
import '../models/backup_settings.dart';
import '../services/settings_repository.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsRepository _repo = SettingsRepository.instance;

  BackupSettings _settings = const BackupSettings();
  BackupSettings get settings => _settings;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  Future<void> init() async {
    _settings = await _repo.loadSettings();
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> updateSettings(BackupSettings newSettings) async {
    _settings = newSettings;
    notifyListeners();
    await _repo.saveSettings(newSettings);
  }

  Future<void> setConsent(bool consent) async {
    _settings = _settings.copyWith(
      userConsentGiven: consent,
      // If user revokes consent, automatically disable auto-backup
      autoBackupEnabled: consent ? _settings.autoBackupEnabled : false,
    );
    notifyListeners();
    await _repo.saveSettings(_settings);
  }

  Future<void> toggleAutoBackup(bool enabled) async {
    _settings = _settings.copyWith(autoBackupEnabled: enabled);
    notifyListeners();
    await _repo.saveSettings(_settings);
  }

  Future<void> toggleWifiOnly(bool wifiOnly) async {
    _settings = _settings.copyWith(wifiOnly: wifiOnly);
    notifyListeners();
    await _repo.saveSettings(_settings);
  }

  Future<void> togglePhotos(bool backupPhotos) async {
    _settings = _settings.copyWith(backupPhotos: backupPhotos);
    notifyListeners();
    await _repo.saveSettings(_settings);
  }

  Future<void> toggleVideos(bool backupVideos) async {
    _settings = _settings.copyWith(backupVideos: backupVideos);
    notifyListeners();
    await _repo.saveSettings(_settings);
  }

  Future<void> toggleChargingOnly(bool chargingOnly) async {
    _settings = _settings.copyWith(chargingOnly: chargingOnly);
    notifyListeners();
    await _repo.saveSettings(_settings);
  }

  Future<void> setBatteryThreshold(int threshold) async {
    _settings = _settings.copyWith(minBatteryThreshold: threshold);
    notifyListeners();
    await _repo.saveSettings(_settings);
  }

  Future<void> setMaxVideoSize(int? maxBytes) async {
    _settings = _settings.copyWith(maxVideoSizeBytes: maxBytes);
    notifyListeners();
    await _repo.saveSettings(_settings);
  }

  Future<void> toggleLocalOnlyMode(bool localOnly) async {
    _settings = _settings.copyWith(localOnlyMode: localOnly);
    notifyListeners();
    await _repo.saveSettings(_settings);
  }

  Future<void> togglePause(bool paused) async {
    _settings = _settings.copyWith(isPaused: paused);
    notifyListeners();
    await _repo.saveSettings(_settings);
  }
}
