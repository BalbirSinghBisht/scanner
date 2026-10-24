class BackupSettings {
  final bool autoBackupEnabled;
  final bool userConsentGiven;
  final bool wifiOnly;
  final bool backupPhotos;
  final bool backupVideos;
  final int minBatteryThreshold;
  final bool chargingOnly;
  final int? maxVideoSizeBytes;
  final bool localOnlyMode;
  final bool isPaused;

  const BackupSettings({
    this.autoBackupEnabled = true,
    this.userConsentGiven = true,
    this.wifiOnly = false,
    this.backupPhotos = true,
    this.backupVideos = true,
    this.minBatteryThreshold = 10,
    this.chargingOnly = false,
    this.maxVideoSizeBytes,
    this.localOnlyMode = false,
    this.isPaused = false,
  });

  BackupSettings copyWith({
    bool? autoBackupEnabled,
    bool? userConsentGiven,
    bool? wifiOnly,
    bool? backupPhotos,
    bool? backupVideos,
    int? minBatteryThreshold,
    bool? chargingOnly,
    int? maxVideoSizeBytes,
    bool? localOnlyMode,
    bool? isPaused,
  }) {
    return BackupSettings(
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      userConsentGiven: userConsentGiven ?? this.userConsentGiven,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      backupPhotos: backupPhotos ?? this.backupPhotos,
      backupVideos: backupVideos ?? this.backupVideos,
      minBatteryThreshold: minBatteryThreshold ?? this.minBatteryThreshold,
      chargingOnly: chargingOnly ?? this.chargingOnly,
      maxVideoSizeBytes: maxVideoSizeBytes ?? this.maxVideoSizeBytes,
      localOnlyMode: localOnlyMode ?? this.localOnlyMode,
      isPaused: isPaused ?? this.isPaused,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'autoBackupEnabled': autoBackupEnabled,
      'userConsentGiven': userConsentGiven,
      'wifiOnly': wifiOnly,
      'backupPhotos': backupPhotos,
      'backupVideos': backupVideos,
      'minBatteryThreshold': minBatteryThreshold,
      'chargingOnly': chargingOnly,
      'maxVideoSizeBytes': maxVideoSizeBytes,
      'localOnlyMode': localOnlyMode,
      'isPaused': isPaused,
    };
  }

  factory BackupSettings.fromMap(Map<String, dynamic> map) {
    return BackupSettings(
      autoBackupEnabled: map['autoBackupEnabled'] as bool? ?? true,
      userConsentGiven: map['userConsentGiven'] as bool? ?? true,
      wifiOnly: map['wifiOnly'] as bool? ?? false,
      backupPhotos: map['backupPhotos'] as bool? ?? true,
      backupVideos: map['backupVideos'] as bool? ?? true,
      minBatteryThreshold: (map['minBatteryThreshold'] as num?)?.toInt() ?? 10,
      chargingOnly: map['chargingOnly'] as bool? ?? false,
      maxVideoSizeBytes: (map['maxVideoSizeBytes'] as num?)?.toInt(),
      localOnlyMode: map['localOnlyMode'] as bool? ?? false,
      isPaused: map['isPaused'] as bool? ?? false,
    );
  }
}
