import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
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

  static const String _lockKey = 'global_backup_sync_lock_ts';

  final StreamController<UploadProgressEvent?> _progressController =
      StreamController<UploadProgressEvent?>.broadcast();
  Stream<UploadProgressEvent?> get progressStream => _progressController.stream;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  bool _isWaitingForNetwork = false;
  bool get isWaitingForNetwork => _isWaitingForNetwork;

  bool _hasAuthError = false;
  bool get hasAuthError => _hasAuthError;

  String? _authErrorMessage;
  String? get authErrorMessage => _authErrorMessage;

  void clearAuthError() {
    _hasAuthError = false;
    _authErrorMessage = null;
  }

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

  static bool _inProcessSyncLock = false;

  /// Waits until network constraints are met, retrying every 15 seconds without pausing background sync.
  Future<bool> _waitForNetwork(BackupSettings settings, SharedPreferences prefs) async {
    var networkOk = await _device.isNetworkPermitted(settings);
    if (networkOk) {
      if (_isWaitingForNetwork) {
        _isWaitingForNetwork = false;
        debugPrint('Internet / Wi-Fi restored! Resuming backup sync...');
      }
      return true;
    }

    _isWaitingForNetwork = true;
    debugPrint('Internet or Wi-Fi is off. Retrying in 15 seconds to check connection...');

    while (!networkOk && _isSyncing && !_isPaused) {
      _progressController.add(UploadProgressEvent(
        item: MediaItem(
          localId: 'network_waiting',
          fileName: 'Waiting for connection',
          mediaType: AppMediaType.other,
          mimeType: 'text/plain',
          fileSize: 0,
          createdAt: DateTime.now(),
        ),
        bytesSent: 0,
        totalBytes: 0,
        progress: 0.0,
        statusMessage: settings.wifiOnly
            ? 'Waiting for Wi-Fi (retrying every 15s)...'
            : 'Waiting for internet (retrying every 15s)...',
      ));

      // Keep lock refreshed and count down 15 seconds before retrying
      for (int i = 0; i < 15 && _isSyncing && !_isPaused; i++) {
        await Future.delayed(const Duration(seconds: 1));
        await prefs.setInt(_lockKey, DateTime.now().millisecondsSinceEpoch);
      }

      if (!_isSyncing || _isPaused) break;

      networkOk = await _device.isNetworkPermitted(settings);
      if (networkOk) {
        _isWaitingForNetwork = false;
        debugPrint('Internet / Wi-Fi restored! Resuming backup sync...');
        return true;
      }
      debugPrint('Internet / Wi-Fi still unavailable. Retrying again in 15 seconds...');
    }

    _isWaitingForNetwork = false;
    return networkOk;
  }

  /// Main synchronization loop with cross-isolate mutex lock, Drive reconciliation, and atomic item claims
  Future<void> startSync({
    required BackupSettings settings,
    bool isManualTrigger = false,
  }) async {
    if (_inProcessSyncLock || _isSyncing) {
      debugPrint('Sync already in progress in this isolate.');
      return;
    }

    // 1. Cross-isolate process lock check
    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastLockMs = prefs.getInt(_lockKey) ?? 0;
    // Strict lock check: if any isolate holds an active lock within the last 15 seconds, yield immediately
    if (nowMs - lastLockMs < 15000) {
      debugPrint('Sync skipped: Another isolate is actively syncing.');
      return;
    }
    await prefs.setInt(_lockKey, nowMs);
    _inProcessSyncLock = true;

    _hasAuthError = false;
    _authErrorMessage = null;

    // Check Google Auth: ensure session is restored from settings if not authenticated yet
    if (!settings.localOnlyMode && !_auth.isAuthenticated) {
      await _auth.restoreSession();
      if (!_auth.isAuthenticated) {
        debugPrint('Sync skipped: Google Drive account credentials not found.');
        _inProcessSyncLock = false;
        await prefs.remove(_lockKey);
        return;
      }
    }

    _isSyncing = true;
    _isPaused = settings.isPaused;

    try {
      // 2. Safely recover interrupted transfers and reset failed items so they are always retried
      await _db.recoverInterruptedUploads(timeoutMinutes: 1);
      await _db.resetAllFailedToReady();

      // Ensure network is available before remote operations (retries every 15s without pausing)
      final initialNetworkOk = await _waitForNetwork(settings, prefs);
      if (!initialNetworkOk) {
        debugPrint('Sync ended: User paused or cancelled during network wait.');
        return;
      }

      // 3. Two-way reconciliation with Google Drive:
      // - If user removed data from Drive, reset SQLite so it automatically re-syncs without clearing app data
      // - If data is already on Drive, mark SQLite as UPLOADED so it never duplicates
      if (!settings.localOnlyMode && _auth.isAuthenticated) {
        try {
          final remoteSummary = await _drive.fetchRemoteFilesSummary();
          await _db.reconcileWithDrive(
            remoteSummary.filesByName,
            remoteSummary.fileIds,
          );
        } catch (e) {
          debugPrint('Drive reconciliation warning: $e');
        }
      }

      // 4. Process pending queue one-by-one atomically
      while (_isSyncing && !_isPaused) {
        // Keep lock alive while active
        await prefs.setInt(_lockKey, DateTime.now().millisecondsSinceEpoch);

        // Verify network & retry every 15s if internet/wifi is off without pausing the background service
        final networkOk = await _waitForNetwork(settings, prefs);
        if (!networkOk) {
          debugPrint('Sync exited: User paused while waiting for network.');
          break;
        }

        final batteryOk = await _device.isBatteryPermitted(settings);
        if (!batteryOk) {
          debugPrint('Sync paused: Battery constraints not met.');
          break;
        }

        // Atomically claim the single next pending upload in an SQLite transaction
        final item = await _db.claimNextPendingUpload(
          includePhotos: settings.backupPhotos,
          includeVideos: settings.backupVideos,
          maxVideoSizeBytes: settings.maxVideoSizeBytes,
        );

        if (item == null) {
          debugPrint('Sync complete: No more pending items in queue.');
          break;
        }

        // Check video size limit
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
    } catch (e) {
      debugPrint('Error during backup sync: $e');
    } finally {
      _isSyncing = false;
      _isWaitingForNetwork = false;
      _inProcessSyncLock = false;
      _currentUploadingItem = null;
      _progressController.add(null);
      await prefs.remove(_lockKey);
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

      // Fallback: check direct Android device paths if localId mapping was lost in background isolate
      if (file == null || !await file.exists()) {
        final possiblePaths = [
          '/storage/emulated/0/DCIM/Camera/${item.fileName}',
          '/storage/emulated/0/DCIM/${item.folderName}/${item.fileName}',
          '/storage/emulated/0/Pictures/${item.folderName}/${item.fileName}',
          '/storage/emulated/0/Movies/${item.folderName}/${item.fileName}',
          '/storage/emulated/0/Download/${item.fileName}',
        ];
        for (final p in possiblePaths) {
          final f = File(p);
          if (await f.exists()) {
            file = f;
            break;
          }
        }
      }

      if (file == null || !await file.exists()) {
        debugPrint('Media item ${item.fileName} (${item.localId}) no longer exists on device storage - removing from database.');
        await _db.deleteMediaItem(item.localId);
        _scanner.invalidateCache(item.localId);
        _progressController.add(UploadProgressEvent(
          item: item,
          bytesSent: 0,
          totalBytes: item.fileSize,
          progress: 0.0,
          statusMessage: 'Item removed (deleted on device)',
        ));
        return;
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
      final isAuth = e.toString().contains('401') ||
          e.toString().contains('authentication') ||
          e.toString().contains('UNAUTHENTICATED');
      if (isAuth) {
        _hasAuthError = true;
        _authErrorMessage =
            'Google Drive authentication expired (401). Please update your access token or reconnect.';
      }

      // Check if failure was caused by internet / network dropping
      final isNetworkPermitted = await _device.isNetworkPermitted(settings);
      final isNetworkError = !isNetworkPermitted ||
          e is SocketException ||
          e.toString().contains('SocketException') ||
          e.toString().contains('Network is unreachable') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Connection timed out') ||
          e.toString().contains('ClientException');

      if (isNetworkError) {
        debugPrint('Upload of ${item.fileName} interrupted by network loss. Will retry every 15s.');
        // Do not increment retryCount for network dropouts; keep ready for retry
        await _db.updateUploadState(
          item.localId,
          UploadState.RETRY_PENDING,
          errorMessage: 'Waiting for network connection',
          retryCount: item.retryCount,
          lastAttemptAt: DateTime.now(),
        );

        _progressController.add(UploadProgressEvent(
          item: item,
          bytesSent: 0,
          totalBytes: item.fileSize,
          progress: 0.0,
          statusMessage: settings.wifiOnly
              ? 'Waiting for Wi-Fi (retrying every 15s)...'
              : 'Waiting for internet (retrying every 15s)...',
        ));
        return;
      }

      final newRetryCount = item.retryCount + 1;
      final finalState = isAuth || newRetryCount >= AppConstants.maxRetryAttempts
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
        statusMessage: isAuth ? 'Authentication Expired (401)' : 'Failed: ${e.toString()}',
      ));

      if (isAuth) {
        // Pause sync immediately so other files don't fail unnecessarily
        _isSyncing = false;
      }
    }
  }

  /// Retries all currently failed uploads
  Future<void> retryFailedUploads(BackupSettings settings) async {
    clearAuthError();
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
