class DashboardStats {
  final int totalAccessiblePhotos;
  final int totalAccessibleVideos;
  final int totalMediaSize;
  final int uploadedFiles;
  final int pendingUploads;
  final int failedUploads;
  final int skippedFiles;
  final int estimatedCloudStorageBytes;
  final double backupCompletionPercentage;
  final String currentUploadStatus;
  final DateTime? lastSuccessfulBackupTime;
  final DateTime? lastScanTime;
  final int duplicateCount;
  final bool isPartialAccess;

  const DashboardStats({
    this.totalAccessiblePhotos = 0,
    this.totalAccessibleVideos = 0,
    this.totalMediaSize = 0,
    this.uploadedFiles = 0,
    this.pendingUploads = 0,
    this.failedUploads = 0,
    this.skippedFiles = 0,
    this.estimatedCloudStorageBytes = 0,
    this.backupCompletionPercentage = 0.0,
    this.currentUploadStatus = 'Idle',
    this.lastSuccessfulBackupTime,
    this.lastScanTime,
    this.duplicateCount = 0,
    this.isPartialAccess = false,
  });

  int get totalAccessibleMedia => totalAccessiblePhotos + totalAccessibleVideos;

  String get formattedTotalMediaSize => _formatBytes(totalMediaSize);
  String get formattedCloudStorage => _formatBytes(estimatedCloudStorageBytes);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
