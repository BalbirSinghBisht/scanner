import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../models/backup_settings.dart';
import '../models/media_item.dart';
import 'auth_service.dart';
import 'database_helper.dart';
import 'device_state_service.dart';
import 'google_drive_service.dart';
import 'media_analysis_service.dart';
import 'media_scanner_service.dart';

class UploadProgressEvent {
  final MediaItem item;
  final int bytesSent;
  final int totalBytes;
  final double progress;
  final String statusMessage;

  const UploadProgressEvent({
    required this.item,
    required this.bytesSent,
    required this.totalBytes,
    required this.progress,
    required this.statusMessage,
  });
}

class BackupSyncService {
  static final BackupSyncService instance = BackupSyncService._init();
  BackupSyncService._init();

  final DatabaseHelper _db = DatabaseHelper.instance;
  final AuthService _auth = AuthService.instance;
  final GoogleDriveService _drive = GoogleDriveService.instance;
  final MediaScannerService _scanner = MediaScannerService.instance;
  final MediaAnalysisService _analysis = MediaAnalysisService.instance;
  final DeviceStateService _device = DeviceStateService.instance;

  final StreamController<UploadProgressEvent?> _progressController =
      StreamController<UploadProgressEvent?>.broadcast();
  Stream<UploadProgressEvent?> get progressStream => _progressController.stream;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  MediaItem? _currentUploadingItem;
  MediaItem? get currentUploadingItem => _currentUploadingItem;

  void pause() {
    _isPaused = true;
  }

  void resume(BackupSettings settings) {
    _isPaused = false;
    if (!_isSyncing) {
      startSync(settings: settings, isManualTrigger: true);
    }
  }

  /// Main synchronization loop
  Future<void> startSync({
    required BackupSettings settings,
    bool isManualTrigger = false,
  }) async {
    // 1. Validate user consent & authorization
    if (!settings.userConsentGiven && !isManualTrigger) {
      debugPrint('Sync skipped: User consent not granted for automatic backup.');
      return;
    }

    if (!settings.autoBackupEnabled && !isManualTrigger) {
      debugPrint('Sync skipped: Automatic backup is disabled in settings.');
      return;
    }

    if (_isSyncing) {
      debugPrint('Sync already in progress.');
      return;
    }

    // Check Google Auth unless local-only testing mode is active
    if (!settings.localOnlyMode && !_auth.isAuthenticated) {
      debugPrint('Sync skipped: Google Drive account is not connected.');
      return;
    }

    _isSyncing = true;
    _isPaused = settings.isPaused;

    try {
      // 2. Safely recover any items stuck in UPLOADING state from previous restarts
      await _db.recoverInterruptedUploads();

      // 3. Process pending queue
      while (_isSyncing && !_isPaused) {
        // Verify network & battery constraints before each batch
        final networkOk = await _device.isNetworkPermitted(settings);
        if (!networkOk) {
          debugPrint('Sync paused: Network constraints not met (e.g., Wi-Fi required).');
          break;
        }

        final batteryOk = await _device.isBatteryPermitted(settings);
        if (!batteryOk) {
          debugPrint('Sync paused: Battery constraints not met (low battery or charging required).');
          break;
        }

        // Fetch next eligible items from SQLite manifest
        final pendingItems = await _db.getPendingUploads(
          includePhotos: settings.backupPhotos,
          includeVideos: settings.backupVideos,
          maxVideoSizeBytes: settings.maxVideoSizeBytes,
          limit: 10,
        );

        if (pendingItems.isEmpty) {
          debugPrint('Sync complete: No more pending items in queue.');
          break;
        }

        for (final item in pendingItems) {
          if (_isPaused || !_isSyncing) break;

          // Double check individual file size against maxVideoSizeBytes
          if (item.mediaType == AppMediaType.video &&
              settings.maxVideoSizeBytes != null &&
              item.fileSize > settings.maxVideoSizeBytes!) {
            await _db.updateUploadState(
              item.localId,
              UploadState.SKIPPED,
              errorMessage:
                  'Exceeds maximum video size limit of ${settings.maxVideoSizeBytes} bytes',
            );
            continue;
          }

          await _processSingleUpload(item, settings);
        }
      }
    } catch (e) {
      debugPrint('Error during backup sync: $e');
    } finally {
      _isSyncing = false;
      _currentUploadingItem = null;
      _progressController.add(null);
    }
  }

  Future<void> _processSingleUpload(MediaItem item, BackupSettings settings) async {
    _currentUploadingItem = item;

    // Transition state to UPLOADING
    await _db.updateUploadState(
      item.localId,
      UploadState.UPLOADING,
      lastAttemptAt: DateTime.now(),
    );

    _progressController.add(UploadProgressEvent(
      item: item,
      bytesSent: 0,
      totalBytes: item.fileSize,
      progress: 0.0,
      statusMessage: 'Preparing ${item.fileName}...',
    ));

    try {
      // 1. Resolve local file handle
      File? file;
      if (item.localFilePath != null) {
        final f = File(item.localFilePath!);
        if (await f.exists()) file = f;
      }
      file ??= await _scanner.getMediaFile(item.localId);

      if (file == null || !await file.exists()) {
        throw BackupException(
          'Media file could not be read from device storage.',
          code: 'FILE_NOT_FOUND',
        );
      }

      // 2. Ensure content hash is computed for duplicate verification
      String? hash = item.contentHash;
      if (hash == null || hash.isEmpty) {
        hash = await _analysis.computeFileHash(file);
        if (hash != null) {
          await _db.updateContentHash(item.localId, hash);
        }
      }

      // 3. Duplicate check: has this identical hash already been uploaded?
      if (hash != null) {
        final duplicateUploaded = await _db.getItemByContentHash(hash);
        if (duplicateUploaded != null && duplicateUploaded.driveFileId != null) {
          // File is identical to an already uploaded file; avoid re-uploading
          await _db.updateUploadState(
            item.localId,
            UploadState.UPLOADED,
            driveFileId: duplicateUploaded.driveFileId,
            uploadedAt: DateTime.now(),
            errorMessage: 'Verified duplicate of ${duplicateUploaded.fileName}',
          );
          return;
        }
      }

      // 4. Local-only simulation mode check
      if (settings.localOnlyMode) {
        // In local-only testing mode, simulate upload verification without hitting Drive API
        await Future.delayed(const Duration(milliseconds: 400));
        await _db.updateUploadState(
          item.localId,
          UploadState.UPLOADED,
          driveFileId: 'local_test_id_${item.localId}',
          uploadedAt: DateTime.now(),
          errorMessage: 'Local-only test upload verified',
        );
        return;
      }

      // 5. Perform actual Google Drive upload
      final uploadedDriveFile = await _drive.uploadFile(
        file: file,
        item: item.copyWith(contentHash: hash),
        onProgress: (sent, total) {
          _progressController.add(UploadProgressEvent(
            item: item,
            bytesSent: sent,
            totalBytes: total,
            progress: total > 0 ? (sent / total).clamp(0.0, 1.0) : 0.0,
            statusMessage: 'Uploading ${item.fileName}...',
          ));
        },
      );

      // 6. Record successful upload in manifest
      await _db.updateUploadState(
        item.localId,
        UploadState.UPLOADED,
        driveFileId: uploadedDriveFile.id,
        uploadedAt: DateTime.now(),
        bytesUploaded: item.fileSize,
        errorMessage: null,
      );

      _progressController.add(UploadProgressEvent(
        item: item,
        bytesSent: item.fileSize,
        totalBytes: item.fileSize,
        progress: 1.0,
        statusMessage: 'Successfully backed up ${item.fileName}',
      ));
    } catch (e) {
      debugPrint('Failed to upload ${item.fileName}: $e');
      final newRetryCount = item.retryCount + 1;
      final finalState = newRetryCount >= AppConstants.maxRetryAttempts
          ? UploadState.FAILED
          : UploadState.RETRY_PENDING;

      await _db.updateUploadState(
        item.localId,
        finalState,
        errorMessage: e.toString(),
        retryCount: newRetryCount,
        lastAttemptAt: DateTime.now(),
      );

      _progressController.add(UploadProgressEvent(
        item: item,
        bytesSent: 0,
        totalBytes: item.fileSize,
        progress: 0.0,
        statusMessage: 'Failed: ${e.toString()}',
      ));
    }
  }

  /// Retries all currently failed uploads
  Future<void> retryFailedUploads(BackupSettings settings) async {
    await _db.resetAllFailedToReady();
    if (!_isSyncing) {
      startSync(settings: settings, isManualTrigger: true);
    }
  }

  void stop() {
    _isSyncing = false;
    _currentUploadingItem = null;
  }
}
