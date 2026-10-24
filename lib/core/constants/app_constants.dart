/// Application-wide constants
class AppConstants {
  static const String appName = 'Media Drive Backup';
  static const String appVersion = '1.0.0';

  // Google Drive folder hierarchy
  static const String rootBackupFolderName = 'PhoneBackup';
  static const String photosFolderName = 'Photos';
  static const String videosFolderName = 'Videos';
  static const String metadataFolderName = 'Metadata';

  // Database
  static const String databaseName = 'media_backup_manifest.db';
  static const int databaseVersion = 2;
  static const String manifestTableName = 'media_manifest';

  // Scan & Upload Batch Sizes
  static const int scanPageSize = 50;
  static const int maxConcurrentUploads = 1; // Sequential & resilient for mobile stability
  static const int defaultLargeFileThresholdBytes = 50 * 1024 * 1024; // 50 MB
  static const int maxRetryAttempts = 5;

  // Drive Scope - narrowest suitable scope for app-created files
  static const String driveFileScope = 'https://www.googleapis.com/auth/drive.file';
}
