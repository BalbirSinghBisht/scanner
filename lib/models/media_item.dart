enum AppMediaType {
  image,
  video,
  other,
}

enum UploadState {
  DISCOVERED,
  ANALYSING,
  READY_TO_UPLOAD,
  UPLOADING,
  UPLOADED,
  RETRY_PENDING,
  FAILED,
  SKIPPED,
}

class MediaItem {
  final String localId;
  final String fileName;
  final AppMediaType mediaType;
  final String mimeType;
  final int fileSize;
  final int? width;
  final int? height;
  final int? durationSeconds;
  final DateTime createdAt;
  final DateTime? modifiedAt;
  final String? contentHash;
  final String? driveFileId;
  final UploadState uploadState;
  final DateTime? lastAttemptAt;
  final DateTime? uploadedAt;
  final String? errorMessage;
  final int retryCount;
  final int bytesUploaded;
  final String? driveFolderPath;
  final String? localFilePath;
  final String? folderName;

  const MediaItem({
    required this.localId,
    required this.fileName,
    required this.mediaType,
    required this.mimeType,
    required this.fileSize,
    this.width,
    this.height,
    this.durationSeconds,
    required this.createdAt,
    this.modifiedAt,
    this.contentHash,
    this.driveFileId,
    this.uploadState = UploadState.DISCOVERED,
    this.lastAttemptAt,
    this.uploadedAt,
    this.errorMessage,
    this.retryCount = 0,
    this.bytesUploaded = 0,
    this.driveFolderPath,
    this.localFilePath,
    this.folderName,
  });

  bool get isUploaded => uploadState == UploadState.UPLOADED;
  bool get isFailed => uploadState == UploadState.FAILED;
  bool get isPending =>
      uploadState == UploadState.READY_TO_UPLOAD ||
      uploadState == UploadState.RETRY_PENDING;
  bool get isUploading => uploadState == UploadState.UPLOADING;

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get formattedDuration {
    if (durationSeconds == null || durationSeconds == 0) return '';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedDimensions {
    if (width != null && height != null && width! > 0 && height! > 0) {
      return '${width}x$height';
    }
    return '';
  }

  /// Builds folder path based on device root folder and phone album folder, e.g. PhoneBackup/Pixel_7/Camera
  String computeTargetFolderPath({String deviceFolder = 'Phone_Device'}) {
    return 'PhoneBackup/$deviceFolder/$displayFolderName';
  }

  String get displayFolderName {
    if (folderName != null && folderName!.trim().isNotEmpty) {
      final name = folderName!.trim();
      if (name.toUpperCase() == 'DCIM') return 'Camera';
      return name;
    }
    if (localFilePath != null && localFilePath!.isNotEmpty) {
      final parts = localFilePath!.split(RegExp(r'[\\/]'));
      if (parts.length >= 2) {
        final parent = parts[parts.length - 2];
        if (parent.isNotEmpty &&
            parent != '0' &&
            parent != 'emulated' &&
            parent != 'storage' &&
            parent != 'sdcard') {
          if (parent.toUpperCase() == 'DCIM') return 'Camera';
          return parent;
        }
      }
    }
    return mediaType == AppMediaType.video ? 'Videos' : 'Camera';
  }

  MediaItem copyWith({
    String? localId,
    String? fileName,
    AppMediaType? mediaType,
    String? mimeType,
    int? fileSize,
    int? width,
    int? height,
    int? durationSeconds,
    DateTime? createdAt,
    DateTime? modifiedAt,
    String? contentHash,
    String? driveFileId,
    UploadState? uploadState,
    DateTime? lastAttemptAt,
    DateTime? uploadedAt,
    String? errorMessage,
    int? retryCount,
    int? bytesUploaded,
    String? driveFolderPath,
    String? localFilePath,
    String? folderName,
  }) {
    return MediaItem(
      localId: localId ?? this.localId,
      fileName: fileName ?? this.fileName,
      mediaType: mediaType ?? this.mediaType,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      width: width ?? this.width,
      height: height ?? this.height,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      contentHash: contentHash ?? this.contentHash,
      driveFileId: driveFileId ?? this.driveFileId,
      uploadState: uploadState ?? this.uploadState,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      retryCount: retryCount ?? this.retryCount,
      bytesUploaded: bytesUploaded ?? this.bytesUploaded,
      driveFolderPath: driveFolderPath ?? this.driveFolderPath,
      localFilePath: localFilePath ?? this.localFilePath,
      folderName: folderName ?? this.folderName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'local_id': localId,
      'file_name': fileName,
      'media_type': mediaType.name,
      'mime_type': mimeType,
      'file_size': fileSize,
      'width': width,
      'height': height,
      'duration_seconds': durationSeconds,
      'created_at': createdAt.millisecondsSinceEpoch,
      'modified_at': modifiedAt?.millisecondsSinceEpoch,
      'content_hash': contentHash,
      'drive_file_id': driveFileId,
      'upload_state': uploadState.name,
      'last_attempt_at': lastAttemptAt?.millisecondsSinceEpoch,
      'uploaded_at': uploadedAt?.millisecondsSinceEpoch,
      'error_message': errorMessage,
      'retry_count': retryCount,
      'bytes_uploaded': bytesUploaded,
      'drive_folder_path': driveFolderPath,
      'local_file_path': localFilePath,
      'folder_name': folderName,
    };
  }

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is num) return DateTime.fromMillisecondsSinceEpoch(val.toInt());
    if (val is String) {
      final asInt = int.tryParse(val);
      if (asInt != null) return DateTime.fromMillisecondsSinceEpoch(asInt);
      return DateTime.tryParse(val);
    }
    return null;
  }

  static int? _parseInt(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val);
    return null;
  }

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    return MediaItem(
      localId: map['local_id'] as String,
      fileName: map['file_name'] as String? ?? 'media_file',
      mediaType: AppMediaType.values.firstWhere(
        (e) => e.name == map['media_type'],
        orElse: () => AppMediaType.image,
      ),
      mimeType: map['mime_type'] as String? ?? 'application/octet-stream',
      fileSize: _parseInt(map['file_size']) ?? 0,
      width: _parseInt(map['width']),
      height: _parseInt(map['height']),
      durationSeconds: _parseInt(map['duration_seconds']),
      createdAt: _parseDate(map['created_at']) ?? DateTime.now(),
      modifiedAt: _parseDate(map['modified_at']),
      contentHash: map['content_hash'] as String?,
      driveFileId: map['drive_file_id'] as String?,
      uploadState: UploadState.values.firstWhere(
        (e) => e.name == map['upload_state'],
        orElse: () => UploadState.DISCOVERED,
      ),
      lastAttemptAt: _parseDate(map['last_attempt_at']),
      uploadedAt: _parseDate(map['uploaded_at']),
      errorMessage: map['error_message'] as String?,
      retryCount: _parseInt(map['retry_count']) ?? 0,
      bytesUploaded: _parseInt(map['bytes_uploaded']) ?? 0,
      driveFolderPath: map['drive_folder_path'] as String?,
      localFilePath: map['local_file_path'] as String?,
      folderName: map['folder_name'] as String?,
    );
  }
}
