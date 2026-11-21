import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static const String _lockKey = 'global_backup_sync_lock_ts';
  Timer? _lockHeartbeatTimer;

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
  final Set<String> _activeUploadingIds = {};
  final Set<String> _activeUploadingFileKeys = {};
  bool _isLargeUploadInFlight = false;

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

  void _startLockHeartbeat(SharedPreferences prefs) {
    _lockHeartbeatTimer?.cancel();
    _lockHeartbeatTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (_isSyncing) {
        try {
          await prefs.setInt(_lockKey, DateTime.now().millisecondsSinceEpoch);
        } catch (_) {}
      }
    });
  }

  void _stopLockHeartbeat(SharedPreferences prefs) {
    _lockHeartbeatTimer?.cancel();
    _lockHeartbeatTimer = null;
    try {
      prefs.remove(_lockKey);
    } catch (_) {}
  }

  /// Waits until network constraints are met, retrying every 15 seconds without pausing background sync.
  Future<bool> _waitForNetwork(
    BackupSettings settings,
    SharedPreferences prefs,
  ) async {
    var networkOk = await _device.isNetworkPermitted(settings);
    if (networkOk) {
      if (_isWaitingForNetwork) {
        _isWaitingForNetwork = false;
        debugPrint('Internet / Wi-Fi restored! Resuming backup sync...');
      }
      return true;
    }

    _isWaitingForNetwork = true;
    debugPrint(
      'Internet or Wi-Fi is off. Retrying in 15 seconds to check connection...',
    );

    while (!networkOk && _isSyncing && !_isPaused) {
      _progressController.add(
        UploadProgressEvent(
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
        ),
      );

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
      debugPrint(
        'Internet / Wi-Fi still unavailable. Retrying again in 15 seconds...',
      );
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
      if (isManualTrigger) {
        debugPrint(
          '[BackupSyncService] Manual sync trigger received while continuous sync is active. Re-checking Google Drive...',
        );
        if (!settings.localOnlyMode && _auth.isAuthenticated) {
          try {
            final folderExists = await _drive.doesDeviceFolderExist();
            if (!folderExists) {
              debugPrint(
                '[BackupSyncService] Device folder removed on Drive! Resetting all items to READY_TO_UPLOAD...',
              );
              await _drive.clearFolderCache();
              await _db.resetAllUploadedToReady();
              await _drive.deleteEmptyDriveFolders();
            } else {
              await _drive.clearFolderCache();
              final remoteSummary = await _drive.fetchRemoteFilesSummary();
              if (remoteSummary.success) {
                final resetCount = await _db.reconcileWithDrive(
                  remoteSummary.fileIds,
                  remoteSummary.idsByLocalId,
                  remoteSummary.idsByContentHash,
                );
                debugPrint(
                  '[BackupSyncService] Reconciled with Drive: $resetCount items reset to READY_TO_UPLOAD',
                );
              }
            }
            await _indexSentAndBackgroundMedia(settings);
          } catch (e) {
            debugPrint(
              '[BackupSyncService] Manual trigger reconciliation error: $e',
            );
          }
        }
      } else {
        debugPrint('Sync already in progress in this isolate.');
      }
      return;
    }

    // 1. Cross-isolate process lock check
    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastLockMs = prefs.getInt(_lockKey) ?? 0;
    // Strict lock check: if any isolate holds an active lock within the last 10 seconds, yield immediately
    // Unless this is a manual trigger, which always takes precedence and resets lock
    if (!isManualTrigger && (nowMs - lastLockMs < 10000)) {
      debugPrint('Sync skipped: Another isolate is actively syncing.');
      return;
    }
    await prefs.setInt(_lockKey, nowMs);
    _inProcessSyncLock = true;
    _startLockHeartbeat(prefs);

    _hasAuthError = false;
    _authErrorMessage = null;

    // Check Google Auth: ensure session is restored from settings if not authenticated yet
    if (!settings.localOnlyMode && !_auth.isAuthenticated) {
      await _auth.restoreSession();
      if (!_auth.isAuthenticated) {
        debugPrint('Sync skipped: Google Drive account credentials not found.');
        _stopLockHeartbeat(prefs);
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
          final folderExists = await _drive.doesDeviceFolderExist();
          if (!folderExists) {
            debugPrint(
              '[BackupSyncService] Device folder removed on Drive! Resetting all items to READY_TO_UPLOAD...',
            );
            await _drive.clearFolderCache();
            await _db.resetAllUploadedToReady();
          } else {
            await _drive.cleanDuplicateDriveFiles();
            await _drive.cleanDuplicateDriveFolders();
            final remoteSummary = await _drive.fetchRemoteFilesSummary();
            if (remoteSummary.success) {
              await _db.reconcileWithDrive(
                remoteSummary.fileIds,
                remoteSummary.idsByLocalId,
                remoteSummary.idsByContentHash,
              );
            } else {
              debugPrint(
                '[BackupSyncService] Skipping Drive reconciliation: remote query failed or unauthenticated.',
              );
            }
          }
        } catch (e) {
          debugPrint('Drive reconciliation warning: $e');
        }
      }

      // 4. Parallel Upfront Album Folder Creation:
      // Pre-creates ONLY folders that actually contain pics and videos data upfront in parallel.
      // If a folder has no pictures or videos, it is NOT created on Drive.
      if (!settings.localOnlyMode && _auth.isAuthenticated) {
        try {
          // Index background Sent media (e.g. WhatsApp Sent) for sync without showing in UI
          await _indexSentAndBackgroundMedia(settings);

          // Pre-ensure root and device folder exist ONCE upfront before any parallel uploads start
          await _drive.ensureDeviceBackupFolder();

          // Clean any duplicate or empty folders on Drive so only folders with actual data remain
          await _drive.cleanDuplicateDriveFolders();
          await _drive.deleteEmptyDriveFolders();
        } catch (e) {
          debugPrint(
            '[BackupSyncService] Upfront folder pre-creation warning: $e',
          );
        }
      }

      // 5. Continuous Library Observer:
      // Listens for any new photos/videos taken while syncing is active and immediately indexes them
      _scanner.startObservingLibraryChanges(() async {
        debugPrint(
          '[BackupSyncService] New media detected on device! Indexing and prioritizing...',
        );
        try {
          await _scanner.scanMedia(isBackground: true);
          await _indexSentAndBackgroundMedia(settings);
        } catch (e) {
          debugPrint('[BackupSyncService] Live index warning: $e');
        }
      });

      // 6. Process pending queue strictly in DESCENDING order (latest created media always first)
      final isWifi = await _device.isWifiConnection();
      final batchSize = isWifi
          ? AppConstants.batchSizeWifi
          : AppConstants.batchSizeMobile;
      debugPrint(
        'Starting continuous batched backup (batch size: $batchSize records, Wi-Fi: $isWifi, Order: DESC)...',
      );

      await _runBatchedSync(settings, prefs);
    } catch (e) {
      debugPrint('Error during backup sync: $e');
    } finally {
      _stopLockHeartbeat(prefs);
      _isSyncing = false;
      _isWaitingForNetwork = false;
      _inProcessSyncLock = false;
      _currentUploadingItem = null;
      _activeUploadingIds.clear();
      _activeUploadingFileKeys.clear();
      _isLargeUploadInFlight = false;
      _progressController.add(null);
    }
  }

  Future<void> _runBatchedSync(
    BackupSettings settings,
    SharedPreferences prefs,
  ) async {
    while (_isSyncing && !_isPaused) {
      // Keep lock alive while active
      await prefs.setInt(_lockKey, DateTime.now().millisecondsSinceEpoch);

      // Verify network & retry every 15s if internet/wifi is off without pausing or stopping
      final networkOk = await _waitForNetwork(settings, prefs);
      if (!networkOk) {
        if (!_isSyncing || _isPaused) break;
        continue;
      }

      final batteryOk = await _device.isBatteryPermitted(settings);
      if (!batteryOk) {
        debugPrint(
          '[BackupSyncService] Battery constraints not met. Waiting for charger without stopping sync...',
        );
        _progressController.add(
          UploadProgressEvent(
            item: MediaItem(
              localId: 'battery_waiting',
              fileName: 'Waiting for battery constraint',
              mediaType: AppMediaType.other,
              mimeType: 'text/plain',
              fileSize: 0,
              createdAt: DateTime.now(),
            ),
            bytesSent: 0,
            totalBytes: 0,
            progress: 0.0,
            statusMessage: 'Battery low / charging required by settings. Waiting for power...',
          ),
        );
        await Future.delayed(const Duration(seconds: 15));
        continue;
      }

      final isWifi = await _device.isWifiConnection();
      final batchSize = isWifi
          ? AppConstants
                .batchSizeWifi // 10
          : AppConstants.batchSizeMobile; // 5

      final now = DateTime.now();
      // Only media inside the rolling two-month window is eligible on either
      // Wi-Fi or mobile data. Older media stays local and is never claimed.
      final syncCutoff = DateTime(
        now.year,
        now.month - BackupSettings.driveSyncWindowMonths,
        now.day,
        now.hour,
        now.minute,
        now.second,
      );

      List<MediaItem> batch = await _db.claimNextPendingUploadBatch(
        includePhotos: settings.backupPhotos,
        includeVideos: settings.backupVideos,
        maxVideoSizeBytes: settings.maxVideoSizeBytes,
        minCreatedAt: syncCutoff,
        batchSize: batchSize,
        includeLockedFolders: settings.syncLockedFolders,
      );

      // If batch is empty, check for Wi-Fi wait, quick scan for incoming media, or continuous monitoring
      if (batch.isEmpty) {
        // Before resting, run a quick scan to detect any newly captured photos or incoming media
        try {
          await _scanner.scanMedia(isBackground: true);
          await _indexSentAndBackgroundMedia(settings);
        } catch (_) {}

        // Try claiming again with any freshly scanned items (which sort to top because DESC)
        batch = await _db.claimNextPendingUploadBatch(
          includePhotos: settings.backupPhotos,
          includeVideos: settings.backupVideos,
          maxVideoSizeBytes: settings.maxVideoSizeBytes,
          minCreatedAt: syncCutoff,
          batchSize: batchSize,
          includeLockedFolders: settings.syncLockedFolders,
        );

        if (batch.isEmpty) {
          // If local queue is empty, check if user removed files or folders on Google Drive!
          if (!settings.localOnlyMode && _auth.isAuthenticated) {
            try {
              final folderExists = await _drive.doesDeviceFolderExist();
              if (!folderExists) {
                debugPrint(
                  '[BackupSyncService] Device folder removed on Google Drive! Clearing folder cache and resetting all uploads...',
                );
                await _drive.clearFolderCache();
                final count = await _db.resetAllUploadedToReady();
                debugPrint(
                  '[BackupSyncService] Reset $count items to READY_TO_UPLOAD. Restarting upload...',
                );
                await _drive.deleteEmptyDriveFolders();
                continue; // Loop again, claim newly reset items, and start uploading immediately!
              }

              final remoteSummary = await _drive.fetchRemoteFilesSummary();
              if (remoteSummary.success) {
                final resetCount = await _db.reconcileWithDrive(
                  remoteSummary.fileIds,
                  remoteSummary.idsByLocalId,
                  remoteSummary.idsByContentHash,
                );
                if (resetCount > 0) {
                  debugPrint(
                    '[BackupSyncService] Detected $resetCount files removed from Drive! Immediately resuming sync...',
                  );
                  await _drive.clearFolderCache();
                  continue; // Loop again, claim newly reset items, and start uploading immediately!
                }
              }
            } catch (e) {
              debugPrint('[BackupSyncService] Drive remote check error: $e');
            }
          }

          // All existing media is up to date: keep continuous sync active and wait for new media
          _progressController.add(
            UploadProgressEvent(
              item: MediaItem(
                localId: 'continuous_sync_active',
                fileName: 'All media backed up. Continuous sync active...',
                mediaType: AppMediaType.other,
                mimeType: 'text/plain',
                fileSize: 0,
                createdAt: DateTime.now(),
              ),
              bytesSent: 0,
              totalBytes: 0,
              progress: 1.0,
              statusMessage: 'Up to date. Continuous sync active (monitoring for new media)...',
            ),
          );

          // Pause 5 seconds while keeping lock active, never terminating!
          for (int s = 0; s < 5 && _isSyncing && !_isPaused; s++) {
            await Future.delayed(const Duration(seconds: 1));
          }
          continue;
        }
      }

      debugPrint(
        '[BackupSyncService] Syncing batch of ${batch.length} items strictly DESC (Wi-Fi: $isWifi)...',
      );

      // Process all 5-10 items in the batch concurrently in parallel!
      await Future.wait(batch.map((item) => _uploadBatchItem(item, settings)));
    }
  }

  Future<void> _uploadBatchItem(MediaItem item, BackupSettings settings) async {
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
      return;
    }

    // Heavy file guard (>50MB): serialize with other large files to protect mobile RAM and CPU
    final isLargeFile =
        item.fileSize > AppConstants.defaultLargeFileThresholdBytes;
    if (isLargeFile) {
      while (_isLargeUploadInFlight && _isSyncing && !_isPaused) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
      _isLargeUploadInFlight = true;
    }

    try {
      await _processSingleUpload(item, settings);
    } finally {
      if (isLargeFile) {
        _isLargeUploadInFlight = false;
      }
    }
  }

  Future<void> _processSingleUpload(
    MediaItem item,
    BackupSettings settings,
  ) async {
    final fileKey = item.contentHash?.isNotEmpty == true
        ? item.contentHash!
        : item.localId;
    if (_activeUploadingFileKeys.contains(fileKey)) {
      debugPrint(
        '[BackupSyncService] Skipping duplicate in-flight upload for $fileKey',
      );
      return;
    }
    _activeUploadingFileKeys.add(fileKey);
    _currentUploadingItem = item;
    _activeUploadingIds.add(item.localId);

    // Transition state to UPLOADING
    await _db.updateUploadState(
      item.localId,
      UploadState.UPLOADING,
      lastAttemptAt: DateTime.now(),
    );

    _progressController.add(
      UploadProgressEvent(
        item: item,
        bytesSent: 0,
        totalBytes: item.fileSize,
        progress: 0.0,
        statusMessage: 'Preparing ${item.fileName}...',
      ),
    );

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
        debugPrint(
          'Media item ${item.fileName} (${item.localId}) no longer exists on device storage - removing from database.',
        );
        await _db.deleteMediaItem(item.localId);
        _scanner.invalidateCache(item.localId);
        _progressController.add(
          UploadProgressEvent(
            item: item,
            bytesSent: 0,
            totalBytes: item.fileSize,
            progress: 0.0,
            statusMessage: 'Item removed (deleted on device)',
          ),
        );
        return;
      }

      // Check if this item was already marked UPLOADED (e.g. by duplicate resolution of an earlier item)
      final currentDbItem = await _db.getItemByLocalId(item.localId);
      if (currentDbItem != null &&
          currentDbItem.uploadState == UploadState.UPLOADED) {
        debugPrint(
          '[BackupSyncService] Item ${item.fileName} was already marked UPLOADED as a duplicate.',
        );
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

      // 3. Duplicate check: has this identical hash or file name already been uploaded?
      if (hash != null) {
        final duplicateUploaded = await _db.getItemByContentHash(hash);
        if (duplicateUploaded != null &&
            duplicateUploaded.driveFileId != null &&
            duplicateUploaded.localId != item.localId) {
          // File is identical to an already uploaded file; avoid re-uploading
          await _db.updateUploadState(
            item.localId,
            UploadState.UPLOADED,
            driveFileId: duplicateUploaded.driveFileId,
            uploadedAt: DateTime.now(),
            errorMessage: 'Verified duplicate of ${duplicateUploaded.fileName}',
          );
          await _db.markDuplicatesUploadedByHash(
            contentHash: hash,
            driveFileId: duplicateUploaded.driveFileId!,
            survivingLocalId: item.localId,
          );
          _progressController.add(
            UploadProgressEvent(
              item: item,
              bytesSent: item.fileSize,
              totalBytes: item.fileSize,
              progress: 1.0,
              statusMessage:
                  'Skipped duplicate (identical to ${duplicateUploaded.fileName})',
            ),
          );
          return;
        }

        // Check if any duplicate with this exact contentHash was ALREADY uploaded to Google Drive
        if (!settings.localOnlyMode && _auth.isAuthenticated) {
          final existingDriveId = await _drive.findExistingDriveFile(
            parentFolderId: '',
            fileName: item.fileName,
            fileSize: item.fileSize,
            contentHash: hash,
            localId: item.localId,
          );
          if (existingDriveId != null) {
            debugPrint(
              '[BackupSyncService] Content of ${item.fileName} already exists on Drive ($existingDriveId)! Marking as uploaded.',
            );
            await _db.updateUploadState(
              item.localId,
              UploadState.UPLOADED,
              driveFileId: existingDriveId,
              uploadedAt: DateTime.now(),
              errorMessage: 'Duplicate found on Google Drive',
            );
            await _db.markDuplicatesUploadedByHash(
              contentHash: hash,
              driveFileId: existingDriveId,
              survivingLocalId: item.localId,
            );
            _progressController.add(
              UploadProgressEvent(
                item: item,
                bytesSent: item.fileSize,
                totalBytes: item.fileSize,
                progress: 1.0,
                statusMessage: 'Skipped duplicate (already on Google Drive)',
              ),
            );
            return;
          }
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
        _progressController.add(
          UploadProgressEvent(
            item: item,
            bytesSent: item.fileSize,
            totalBytes: item.fileSize,
            progress: 1.0,
            statusMessage: 'Local-only backup verified',
          ),
        );
        return;
      }

      // 5. Perform actual Google Drive upload
      final uploadedDriveFile = await _drive.uploadFile(
        file: file,
        item: item.copyWith(contentHash: hash),
        onProgress: (sent, total) {
          _progressController.add(
            UploadProgressEvent(
              item: item,
              bytesSent: sent,
              totalBytes: total,
              progress: total > 0 ? (sent / total).clamp(0.0, 1.0) : 0.0,
              statusMessage: 'Uploading ${item.fileName}...',
            ),
          );
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

      // Propagate drive_file_id to any duplicate items in manifest so they are never uploaded
      if (hash != null && uploadedDriveFile.id != null) {
        await _db.markDuplicatesUploadedByHash(
          contentHash: hash,
          driveFileId: uploadedDriveFile.id!,
          survivingLocalId: item.localId,
        );
      }
      _progressController.add(
        UploadProgressEvent(
          item: item,
          bytesSent: item.fileSize,
          totalBytes: item.fileSize,
          progress: 1.0,
          statusMessage: 'Successfully backed up ${item.fileName}',
        ),
      );
    } catch (e) {
      debugPrint('Failed to upload ${item.fileName}: $e');
      final isAuth =
          e.toString().contains('401') ||
          e.toString().contains('authentication') ||
          e.toString().contains('UNAUTHENTICATED') ||
          e.toString().contains('invalid_grant') ||
          e.toString().contains('expired or revoked') ||
          e is AuthException;
      if (isAuth) {
        _hasAuthError = true;
        _authErrorMessage =
            'Google Drive token expired (401). Attempting silent background renewal.';
        try {
          final recovered = await _auth.refreshActiveSession();
          if (recovered) {
            _hasAuthError = false;
            _authErrorMessage = null;
          }
        } catch (_) {}
      }

      // Check if failure was caused by internet / network dropping
      final isNetworkPermitted = await _device.isNetworkPermitted(settings);
      final isNetworkError =
          !isNetworkPermitted ||
          e is SocketException ||
          e.toString().contains('SocketException') ||
          e.toString().contains('Network is unreachable') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Connection timed out') ||
          e.toString().contains('ClientException');

      if (isNetworkError) {
        debugPrint(
          'Upload of ${item.fileName} interrupted by network loss. Will retry every 15s.',
        );
        // Do not increment retryCount for network dropouts; keep ready for retry
        await _db.updateUploadState(
          item.localId,
          UploadState.RETRY_PENDING,
          errorMessage: 'Waiting for network connection',
          retryCount: item.retryCount,
          lastAttemptAt: DateTime.now(),
        );

        _progressController.add(
          UploadProgressEvent(
            item: item,
            bytesSent: 0,
            totalBytes: item.fileSize,
            progress: 0.0,
            statusMessage: settings.wifiOnly
                ? 'Waiting for Wi-Fi (retrying every 15s)...'
                : 'Waiting for internet (retrying every 15s)...',
          ),
        );
        return;
      }

      final newRetryCount = item.retryCount + 1;
      final finalState =
          (!isAuth && newRetryCount >= AppConstants.maxRetryAttempts)
          ? UploadState.FAILED
          : UploadState.RETRY_PENDING;

      await _db.updateUploadState(
        item.localId,
        finalState,
        errorMessage: e.toString(),
        retryCount: newRetryCount,
        lastAttemptAt: DateTime.now(),
      );

      _progressController.add(
        UploadProgressEvent(
          item: item,
          bytesSent: 0,
          totalBytes: item.fileSize,
          progress: 0.0,
          statusMessage: isAuth
              ? 'Authentication Expired (401)'
              : 'Failed: ${e.toString()}',
        ),
      );

      if (isAuth) {
        // Pause sync immediately so other files don't fail unnecessarily
        _isSyncing = false;
      }
    } finally {
      _activeUploadingFileKeys.remove(fileKey);
      _activeUploadingIds.remove(item.localId);
      if (_activeUploadingIds.isEmpty) {
        _currentUploadingItem = null;
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

  /// Derives an intuitive, platform-specific album folder name for Google Drive backups
  /// (e.g. WhatsApp Sent, WhatsApp Images, Telegram Video Sent, Messenger, Instagram, Signal Sent).
  static String derivePlatformAlbumName(
    String filePath, {
    required bool isVideo,
  }) {
    final normalized = filePath.replaceAll(r'\', '/');
    final lower = normalized.toLowerCase();
    final isSent = lower.contains('/sent/') || lower.endsWith('/sent');
    final isPrivate = lower.contains('/private/') || lower.endsWith('/private');

    // WhatsApp Business
    if (lower.contains('com.whatsapp.w4b') ||
        lower.contains('whatsapp business')) {
      if (isSent) {
        return isVideo
            ? 'WhatsApp Business Video Sent'
            : 'WhatsApp Business Sent';
      }
      if (isPrivate) {
        return isVideo
            ? 'WhatsApp Business Video Private'
            : 'WhatsApp Business Private';
      }
      return isVideo ? 'WhatsApp Business Video' : 'WhatsApp Business Images';
    }

    // WhatsApp
    if (lower.contains('com.whatsapp') || lower.contains('/whatsapp/')) {
      if (isSent) return isVideo ? 'WhatsApp Video Sent' : 'WhatsApp Sent';
      if (isPrivate) {
        return isVideo ? 'WhatsApp Video Private' : 'WhatsApp Private';
      }
      return isVideo ? 'WhatsApp Video' : 'WhatsApp Images';
    }

    // Telegram
    if (lower.contains('telegram')) {
      if (isSent) return isVideo ? 'Telegram Video Sent' : 'Telegram Sent';
      return isVideo ? 'Telegram Video' : 'Telegram Images';
    }

    // Facebook Messenger
    if (lower.contains('com.facebook.orca') || lower.contains('/messenger/')) {
      if (isSent) return 'Messenger Sent';
      return isVideo ? 'Messenger Video' : 'Messenger';
    }

    // Facebook
    if (lower.contains('com.facebook.katana') || lower.contains('/facebook/')) {
      if (isSent) return 'Facebook Sent';
      return isVideo ? 'Facebook Video' : 'Facebook';
    }

    // Instagram
    if (lower.contains('com.instagram.android') ||
        lower.contains('/instagram/')) {
      if (isSent) return 'Instagram Sent';
      return isVideo ? 'Instagram Video' : 'Instagram';
    }

    // Threads
    if (lower.contains('/threads/')) {
      return 'Threads';
    }

    // Snapchat
    if (lower.contains('snapchat')) {
      if (isSent) return 'Snapchat Sent';
      return isVideo ? 'Snapchat Video' : 'Snapchat';
    }

    // Signal
    if (lower.contains('org.thoughtcrime.securesms') ||
        lower.contains('/signal/')) {
      if (isSent) return isVideo ? 'Signal Video Sent' : 'Signal Sent';
      return isVideo ? 'Signal Video' : 'Signal';
    }

    // Viber
    if (lower.contains('com.viber.voip') || lower.contains('/viber/')) {
      if (isSent) return isVideo ? 'Viber Video Sent' : 'Viber Sent';
      return isVideo ? 'Viber Video' : 'Viber Images';
    }

    // Discord
    if (lower.contains('com.discord') || lower.contains('/discord/')) {
      return 'Discord';
    }

    // LINE
    if (lower.contains('line')) {
      if (isSent) return 'LINE Sent';
      return isVideo ? 'LINE Video' : 'LINE';
    }

    // WeChat
    if (lower.contains('weixin') ||
        lower.contains('wechat') ||
        lower.contains('tencent')) {
      if (isSent) return 'WeChat Sent';
      return isVideo ? 'WeChat Video' : 'WeChat';
    }

    // Twitter / X
    if (lower.contains('/twitter/') || lower.contains('/x/')) {
      if (isSent) return 'Twitter Sent';
      return isVideo ? 'Twitter Video' : 'Twitter';
    }

    // Reddit
    if (lower.contains('/reddit/')) {
      return 'Reddit';
    }

    // Pinterest
    if (lower.contains('/pinterest/')) {
      return 'Pinterest';
    }

    // Google Messages / RCS
    if (lower.contains('com.google.android.apps.messaging') ||
        lower.contains('/messages/')) {
      if (isSent) return 'Messages Sent';
      return isVideo ? 'Messages Video' : 'Messages';
    }

    // Skype
    if (lower.contains('com.skype.raider') || lower.contains('/skype/')) {
      if (isSent) return 'Skype Sent';
      return isVideo ? 'Skype Video' : 'Skype';
    }

    // Bluetooth
    if (lower.contains('/bluetooth/')) {
      return 'Bluetooth';
    }

    // Download
    if (lower.contains('/download/') || lower.contains('/downloads/')) {
      return 'Download';
    }

    // Fallback: examine parent and grandparent directory
    final parts = normalized.split('/');
    if (parts.length >= 2) {
      final parent = parts[parts.length - 2];
      if (parent.toLowerCase() == 'sent' && parts.length >= 3) {
        final grandParent = parts[parts.length - 3];
        return '$grandParent Sent';
      }
      if (parent.toLowerCase() == 'private' && parts.length >= 3) {
        final grandParent = parts[parts.length - 3];
        return '$grandParent Private';
      }
      if (parent.isNotEmpty &&
          parent != '0' &&
          parent != 'emulated' &&
          parent != 'storage') {
        return parent;
      }
    }

    return isVideo ? 'Videos' : 'Camera';
  }

  /// Indexes sent and received media from any messaging and social platform
  /// (WhatsApp, WhatsApp Business, Telegram, Signal, Instagram, Messenger, Snapchat,
  /// Viber, Discord, LINE, WeChat, Twitter/X, Reddit, Messages, Downloads, Bluetooth, etc.)
  /// strictly for Google Drive syncing.
  Future<void> _indexSentAndBackgroundMedia(BackupSettings settings) async {
    if (!Platform.isAndroid) return;
    try {
      final candidateDirs = <String>{
        // WhatsApp & WhatsApp Business (Received, Sent, Private, Documents)
        '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images',
        '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/Sent',
        '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/Private',
        '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video',
        '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video/Sent',
        '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video/Private',
        '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents',
        '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents/Sent',
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Images',
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Images/Sent',
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Images/Private',
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Video',
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Video/Sent',
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Video/Private',
        '/storage/emulated/0/Pictures/WhatsApp',
        '/storage/emulated/0/Pictures/WhatsApp/Sent',
        '/storage/emulated/0/Pictures/WhatsApp/Private',
        '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Images',
        '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Images/Sent',
        '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Images/Private',
        '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Video',
        '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Video/Sent',
        '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Video/Private',
        '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Documents',
        '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Documents/Sent',

        // Telegram (Received, Sent, Documents)
        '/storage/emulated/0/Telegram/Telegram Images',
        '/storage/emulated/0/Telegram/Telegram Images/Sent',
        '/storage/emulated/0/Telegram/Telegram Video',
        '/storage/emulated/0/Telegram/Telegram Video/Sent',
        '/storage/emulated/0/Telegram/Telegram Documents',
        '/storage/emulated/0/Pictures/Telegram',
        '/storage/emulated/0/Pictures/Telegram/Sent',
        '/storage/emulated/0/Movies/Telegram',
        '/storage/emulated/0/Android/media/org.telegram.messenger/Telegram/Telegram Images',
        '/storage/emulated/0/Android/media/org.telegram.messenger/Telegram/Telegram Video',
        '/storage/emulated/0/Android/media/org.telegram.messenger/Telegram/Telegram Documents',
        '/storage/emulated/0/Android/media/org.telegram.messenger.web/Telegram/Telegram Images',
        '/storage/emulated/0/Android/media/org.telegram.messenger.web/Telegram/Telegram Video',
        '/storage/emulated/0/Android/data/org.telegram.messenger/files/Telegram/Telegram Images',
        '/storage/emulated/0/Android/data/org.telegram.messenger/files/Telegram/Telegram Video',

        // Signal (Received & Sent)
        '/storage/emulated/0/Pictures/Signal',
        '/storage/emulated/0/Pictures/Signal/Sent',
        '/storage/emulated/0/Movies/Signal',
        '/storage/emulated/0/Movies/Signal/Sent',
        '/storage/emulated/0/Signal/Media',
        '/storage/emulated/0/Signal',
        '/storage/emulated/0/Android/media/org.thoughtcrime.securesms',

        // Facebook Messenger & Facebook
        '/storage/emulated/0/Pictures/Messenger',
        '/storage/emulated/0/Pictures/Messenger/Sent',
        '/storage/emulated/0/Movies/Messenger',
        '/storage/emulated/0/Pictures/Facebook',
        '/storage/emulated/0/Pictures/Facebook/Sent',
        '/storage/emulated/0/Movies/Facebook',
        '/storage/emulated/0/DCIM/Facebook',
        '/storage/emulated/0/Android/media/com.facebook.orca',
        '/storage/emulated/0/Android/media/com.facebook.katana',

        // Instagram & Threads
        '/storage/emulated/0/Pictures/Instagram',
        '/storage/emulated/0/Pictures/Instagram/Sent',
        '/storage/emulated/0/Movies/Instagram',
        '/storage/emulated/0/DCIM/Instagram',
        '/storage/emulated/0/Pictures/Threads',
        '/storage/emulated/0/Android/media/com.instagram.android',

        // Snapchat
        '/storage/emulated/0/Snapchat',
        '/storage/emulated/0/Pictures/Snapchat',
        '/storage/emulated/0/Pictures/Snapchat/Sent',
        '/storage/emulated/0/DCIM/Snapchat',
        '/storage/emulated/0/Movies/Snapchat',
        '/storage/emulated/0/Android/media/com.snapchat.android',

        // Viber
        '/storage/emulated/0/viber/media/Viber Images',
        '/storage/emulated/0/viber/media/Viber Images/Sent',
        '/storage/emulated/0/viber/media/Viber Videos',
        '/storage/emulated/0/viber/media/Viber Videos/Sent',
        '/storage/emulated/0/Pictures/Viber',
        '/storage/emulated/0/Movies/Viber',
        '/storage/emulated/0/Android/media/com.viber.voip',

        // Discord
        '/storage/emulated/0/Pictures/Discord',
        '/storage/emulated/0/Download/Discord',
        '/storage/emulated/0/Android/media/com.discord',

        // LINE
        '/storage/emulated/0/Pictures/LINE',
        '/storage/emulated/0/Pictures/LINE/Sent',
        '/storage/emulated/0/Movies/LINE',
        '/storage/emulated/0/LINE',
        '/storage/emulated/0/Android/media/jp.naver.line.android',

        // WeChat
        '/storage/emulated/0/Tencent/MicroMsg/WeiXin',
        '/storage/emulated/0/Pictures/WeChat',
        '/storage/emulated/0/Android/media/com.tencent.mm',

        // Twitter / X
        '/storage/emulated/0/Pictures/Twitter',
        '/storage/emulated/0/Pictures/Twitter/Sent',
        '/storage/emulated/0/Pictures/X',
        '/storage/emulated/0/Android/media/com.twitter.android',

        // Reddit, Pinterest, Tumblr, TikTok
        '/storage/emulated/0/Pictures/Reddit',
        '/storage/emulated/0/Pictures/Pinterest',
        '/storage/emulated/0/Pictures/Tumblr',
        '/storage/emulated/0/Pictures/TikTok',
        '/storage/emulated/0/Movies/TikTok',

        // Google Messages / RCS / SMS / MMS
        '/storage/emulated/0/Pictures/Messages',
        '/storage/emulated/0/Pictures/Messages/Sent',
        '/storage/emulated/0/Download/Messages',
        '/storage/emulated/0/Android/media/com.google.android.apps.messaging',

        // Skype
        '/storage/emulated/0/Pictures/Skype',
        '/storage/emulated/0/Android/media/com.skype.raider',

        // Downloads & Bluetooth
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/storage/emulated/0/Bluetooth',
        '/storage/emulated/0/Download/Telegram',
        '/storage/emulated/0/Download/WhatsApp',
      };

      // Dynamic Discovery: Check all packages under /storage/emulated/0/Android/media/
      try {
        final mediaRoot = Directory('/storage/emulated/0/Android/media');
        if (await mediaRoot.exists()) {
          await for (final pkg in mediaRoot.list(followLinks: false)) {
            if (pkg is Directory) {
              candidateDirs.add(pkg.path);
              try {
                await for (final sub in pkg.list(followLinks: false)) {
                  if (sub is Directory) {
                    candidateDirs.add(sub.path);
                    final sentSub = Directory('${sub.path}/Sent');
                    if (await sentSub.exists()) candidateDirs.add(sentSub.path);
                    final privSub = Directory('${sub.path}/Private');
                    if (await privSub.exists()) candidateDirs.add(privSub.path);
                  }
                }
              } catch (_) {}
            }
          }
        }
      } catch (_) {}

      // Dynamic Discovery: Check any Sent or Private subfolders inside Pictures, Movies, and DCIM
      for (final rootBase in [
        '/storage/emulated/0/Pictures',
        '/storage/emulated/0/Movies',
        '/storage/emulated/0/DCIM',
      ]) {
        try {
          final rootDir = Directory(rootBase);
          if (await rootDir.exists()) {
            await for (final sub in rootDir.list(followLinks: false)) {
              if (sub is Directory) {
                candidateDirs.add(sub.path);
                final sentSub = Directory('${sub.path}/Sent');
                if (await sentSub.exists()) candidateDirs.add(sentSub.path);
                final privSub = Directory('${sub.path}/Private');
                if (await privSub.exists()) candidateDirs.add(privSub.path);
              }
            }
          }
        } catch (_) {}
      }

      const imageExtensions = {
        '.jpg',
        '.jpeg',
        '.png',
        '.webp',
        '.heic',
        '.heif',
        '.avif',
        '.gif',
        '.bmp',
        '.dng',
        '.raw',
        '.cr2',
        '.cr3',
        '.nef',
        '.arw',
        '.orf',
        '.rw2',
      };
      const videoExtensions = {
        '.mp4', '.mkv', '.mov', '.3gp', '.avi', '.webm', '.m4v', '.mpeg',
        '.mpg',
      };

      final existingPaths = await _db.getAllLocalFilePathsSet();

      for (final dirPath in candidateDirs) {
        final dir = Directory(dirPath);
        if (!await dir.exists()) continue;
        if (!settings.syncLockedFolders &&
            MediaScannerService.isPrivateOrLockedPath(null, dirPath)) {
          continue;
        }

        await for (final entity in dir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is! File) continue;
          final path = entity.path;
          final pLower = path.toLowerCase();
          // Filter out statuses, stickers, junk
          if (pLower.contains('status') ||
              pLower.contains('sticker') ||
              pLower.contains('.thumb') ||
              pLower.contains('.cache')) {
            continue;
          }
          if (!settings.syncLockedFolders &&
              MediaScannerService.isPrivateOrLockedPath(null, path)) {
            continue;
          }
          if (existingPaths.contains(path)) continue;

          final dotIndex = path.lastIndexOf('.');
          if (dotIndex == -1) continue;
          final ext = pLower.substring(dotIndex);
          final isImage = imageExtensions.contains(ext);
          final isVideo = videoExtensions.contains(ext);
          if (!isImage && !isVideo) continue;
          if (isImage && !settings.backupPhotos) continue;
          if (isVideo && !settings.backupVideos) continue;

          final stat = await entity.stat();
          if (stat.size <= 0) continue;
          final fileName = path.split(RegExp(r'[\\/]')).last;
          existingPaths.add(path);

          final mediaType = isVideo ? AppMediaType.video : AppMediaType.image;
          String mimeType;
          if (isVideo) {
            if (ext == '.mkv') {
              mimeType = 'video/x-matroska';
            } else if (ext == '.mov') {
              mimeType = 'video/quicktime';
            } else if (ext == '.3gp') {
              mimeType = 'video/3gpp';
            } else if (ext == '.webm') {
              mimeType = 'video/webm';
            } else {
              mimeType = 'video/mp4';
            }
          } else {
            if (ext == '.png') {
              mimeType = 'image/png';
            } else if (ext == '.webp') {
              mimeType = 'image/webp';
            } else if (ext == '.heic') {
              mimeType = 'image/heic';
            } else if (ext == '.gif') {
              mimeType = 'image/gif';
            } else if (ext == '.bmp') {
              mimeType = 'image/bmp';
            } else {
              mimeType = 'image/jpeg';
            }
          }

          final localId = 'disk_${path.hashCode.abs()}';
          final folderName = derivePlatformAlbumName(path, isVideo: isVideo);

          final item = MediaItem(
            localId: localId,
            fileName: fileName,
            mediaType: mediaType,
            mimeType: mimeType,
            fileSize: stat.size,
            createdAt: stat.modified,
            modifiedAt: stat.modified,
            localFilePath: path,
            folderName: folderName,
            uploadState: UploadState.READY_TO_UPLOAD,
          );

          await _db.upsertMediaItem(item);
        }
      }
    } catch (e) {
      debugPrint(
        '[BackupSyncService] Background Platform media indexing warning: $e',
      );
    }
  }

  void stop() {
    _isSyncing = false;
    _currentUploadingItem = null;
    _activeUploadingIds.clear();
    _activeUploadingFileKeys.clear();
    _isLargeUploadInFlight = false;
  }
}
