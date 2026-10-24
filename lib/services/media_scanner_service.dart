import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../models/media_item.dart';
import 'database_helper.dart';
import 'device_settings_helper.dart';

class ScanProgressReport {
  final int scannedItems;
  final int totalDiscovered;
  final String currentBatchStatus;
  final bool isCompleted;

  const ScanProgressReport({
    required this.scannedItems,
    required this.totalDiscovered,
    required this.currentBatchStatus,
    this.isCompleted = false,
  });

  double get progress => totalDiscovered > 0
      ? (scannedItems / totalDiscovered).clamp(0.0, 1.0)
      : 0.0;
}

class MediaScannerService {
  static final MediaScannerService instance = MediaScannerService._init();
  MediaScannerService._init();

  final DatabaseHelper _db = DatabaseHelper.instance;

  final StreamController<ScanProgressReport> _scanProgressController =
      StreamController<ScanProgressReport>.broadcast();
  Stream<ScanProgressReport> get scanProgressStream =>
      _scanProgressController.stream;

  PermissionState _lastPermissionState = PermissionState.notDetermined;
  PermissionState get lastPermissionState => _lastPermissionState;

  final Map<String, Uint8List> _thumbnailCache = {};

  bool get isPermissionGranted =>
      _lastPermissionState == PermissionState.authorized ||
      _lastPermissionState == PermissionState.limited;

  bool get isPartialAccess => _lastPermissionState == PermissionState.limited;

  bool _isObservingChanges = false;
  void Function(MethodCall)? _changeCallback;

  /// Starts listening to device media changes (new photos, videos) and triggers auto-sync
  void startObservingLibraryChanges(Future<void> Function() onNewMedia) {
    if (_isObservingChanges) return;
    _isObservingChanges = true;

    _changeCallback = (MethodCall call) async {
      debugPrint('Device media change detected (${call.method}). Auto-scanning new data...');
      await onNewMedia();
    };

    PhotoManager.addChangeCallback(_changeCallback!);
    PhotoManager.startChangeNotify();
  }

  void stopObservingLibraryChanges() {
    if (!_isObservingChanges) return;
    if (_changeCallback != null) {
      PhotoManager.removeChangeCallback(_changeCallback!);
      _changeCallback = null;
    }
    PhotoManager.stopChangeNotify();
    _isObservingChanges = false;
  }

  /// Requests native media library permissions
  Future<PermissionState> requestPermission() async {
    try {
      final state = await PhotoManager.requestPermissionExtend();
      _lastPermissionState = state;
      return state;
    } catch (e) {
      debugPrint('Error requesting media permissions: $e');
      return PermissionState.denied;
    }
  }

  /// Requests essential runtime permissions for continuous, uninterrupted auto-sync:
  /// 1. Photo & Video media storage permission
  /// 2. Notification permission (enables persistent Foreground Service notification on Android 13+)
  /// 3. Battery optimization exemption (prevents Android Doze mode killing background sync)
  Future<void> requestAllAppPermissions() async {
    try {
      await requestPermission();
      await DeviceSettingsHelper.requestNotificationPermission();
    } catch (e) {
      debugPrint('Error requesting media permissions: $e');
    }
  }

  /// Opens the device system settings for this app
  Future<void> openSettings() async {
    await PhotoManager.openSetting();
  }

  /// Retrieves all album / library folders from the device
  Future<List<AssetPathEntity>> getAllAlbums() async {
    try {
      final perm = await requestPermission();
      if (perm == PermissionState.denied || perm == PermissionState.restricted) {
        return [];
      }
      return await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: true,
        onlyAll: false,
      );
    } catch (e) {
      debugPrint('Error getting albums: $e');
      return [];
    }
  }

  /// Scans device media library incrementally using pagination.
  /// Does NOT load heavy full-resolution image/video bytes into RAM.
  Future<List<MediaItem>> scanMedia({
    bool forceFullScan = false,
    DateTime? scanSince,
    bool isBackground = false,
  }) async {
    if (!isBackground) {
      final perm = await requestPermission();
      if (perm == PermissionState.denied || perm == PermissionState.restricted) {
        throw MediaPermissionDeniedException(
          'Media library permission was denied by the user.',
          isPermanentlyDenied: false,
        );
      }
    }

    // Retrieve album collections (Recent / All Photos and Videos)
    List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.common, // Both images and videos
      hasAll: true,
      onlyAll: true,
    );

    // Resilient fallback: if the synthetic "Recent/All" album is empty (e.g. right after granting permissions
    // or on strict OEM ROMs like MIUI/HyperOS), refresh cache and query all concrete folders
    if (albums.isEmpty) {
      await PhotoManager.clearFileCache();
      await Future.delayed(const Duration(milliseconds: 300));
      albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: true,
        onlyAll: false,
      );
    }

    if (albums.isEmpty) {
      // Retry once more after brief delay for OS MediaStore to finish propagating
      await Future.delayed(const Duration(milliseconds: 500));
      albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: true,
        onlyAll: false,
      );
    }

    if (albums.isEmpty) {
      _scanProgressController.add(const ScanProgressReport(
        scannedItems: 0,
        totalDiscovered: 0,
        currentBatchStatus: 'No media albums found on device',
        isCompleted: true,
      ));
      return [];
    }

    AssetPathEntity? recentAlbum;
    for (final a in albums) {
      if (a.isAll) {
        recentAlbum = a;
        break;
      }
    }
    recentAlbum ??= albums.first;
    final List<AssetPathEntity> scanTargets = recentAlbum.isAll ? [recentAlbum] : albums;

    int totalAssetCount = 0;
    for (final album in scanTargets) {
      totalAssetCount += await album.assetCountAsync;
    }

    _scanProgressController.add(ScanProgressReport(
      scannedItems: 0,
      totalDiscovered: totalAssetCount,
      currentBatchStatus: 'Found $totalAssetCount accessible media items. Beginning metadata indexing...',
    ));

    final discoveredList = <MediaItem>[];
    const pageSize = AppConstants.scanPageSize;
    int processedCount = 0;

    for (final album in scanTargets) {
      final albumCount = await album.assetCountAsync;
      final albumPages = (albumCount / pageSize).ceil();
      final maxPages = isBackground ? 2 : albumPages;

      for (int page = 0; page < maxPages && page < albumPages; page++) {
        final List<AssetEntity> entities = await album.getAssetListPaged(
          page: page,
          size: pageSize,
        );

      final batchItems = <MediaItem>[];

      for (final entity in entities) {
        // Fast incremental check: if already indexed and uploaded, skip immediately
        final existingItem = await _db.getItemByLocalId(entity.id);
        if (!forceFullScan &&
            existingItem != null &&
            existingItem.uploadState == UploadState.UPLOADED) {
          processedCount++;
          continue;
        }

        // Fast metadata extraction without loading bytes into memory
        final mediaType = entity.type == AssetType.video
            ? AppMediaType.video
            : AppMediaType.image;

        final mimeType = await entity.mimeTypeAsync ??
            (mediaType == AppMediaType.video ? 'video/mp4' : 'image/jpeg');

        // Fast file size via OS stat
        int fileSize = 0;
        String? filePath;
        try {
          final file = await entity.file;
          if (file != null && await file.exists()) {
            fileSize = await file.length();
            filePath = file.path;
          }
        } catch (_) {
          // Fallback if file handle is restricted
        }

        // Extract folder name accurately
        String? folderName;
        try {
          if (entity.relativePath != null && entity.relativePath!.isNotEmpty) {
            final trimmed = entity.relativePath!.replaceAll(RegExp(r'[\\/]+$'), '');
            final parts = trimmed.split(RegExp(r'[\\/]'));
            if (parts.isNotEmpty) {
              folderName = parts.last;
            }
          }
        } catch (_) {}

        if (folderName == null || folderName.isEmpty) {
          if (filePath != null && filePath.isNotEmpty) {
            final parts = filePath.split(RegExp(r'[\\/]'));
            if (parts.length >= 2) {
              final parent = parts[parts.length - 2];
              if (parent.isNotEmpty && parent != '0' && parent != 'emulated') {
                folderName = parent;
              }
            }
          }
        }
        if (folderName?.toUpperCase() == 'DCIM') {
          folderName = 'Camera';
        }
        folderName ??= (mediaType == AppMediaType.video ? 'Videos' : 'Camera');

        final item = MediaItem(
          localId: entity.id,
          fileName: entity.title?.isNotEmpty == true
              ? entity.title!
              : 'media_${entity.id}.${mediaType == AppMediaType.video ? "mp4" : "jpg"}',
          mediaType: mediaType,
          mimeType: mimeType,
          fileSize: fileSize,
          width: entity.width,
          height: entity.height,
          durationSeconds: entity.duration,
          createdAt: entity.createDateTime,
          modifiedAt: entity.modifiedDateTime,
          uploadState: existingItem?.uploadState ?? UploadState.READY_TO_UPLOAD,
          contentHash: existingItem?.contentHash,
          driveFileId: existingItem?.driveFileId,
          lastAttemptAt: existingItem?.lastAttemptAt,
          uploadedAt: existingItem?.uploadedAt,
          errorMessage: existingItem?.errorMessage,
          retryCount: existingItem?.retryCount ?? 0,
          bytesUploaded: existingItem?.bytesUploaded ?? 0,
          driveFolderPath: existingItem?.driveFolderPath,
          localFilePath: filePath ?? existingItem?.localFilePath,
          folderName: folderName,
        );

        batchItems.add(item);
        discoveredList.add(item);
        processedCount++;
      }

      // Batch persist to SQLite database
      if (batchItems.isNotEmpty) {
        await _db.batchUpsertMediaItems(batchItems);
      }

      _scanProgressController.add(ScanProgressReport(
        scannedItems: processedCount,
        totalDiscovered: totalAssetCount,
        currentBatchStatus: 'Indexed $processedCount of $totalAssetCount items...',
      ));
    }
  }

    _scanProgressController.add(ScanProgressReport(
      scannedItems: processedCount,
      totalDiscovered: totalAssetCount,
      currentBatchStatus: 'Scan complete! Indexed $processedCount items.',
      isCompleted: true,
    ));

    return discoveredList;
  }

  /// Helper to get direct File instance for an AssetEntity ID when ready to upload or hash
  Future<File?> getMediaFile(String assetId) async {
    final asset = await AssetEntity.fromId(assetId);
    if (asset != null) {
      try {
        final origin = await asset.originFile;
        if (origin != null && await origin.exists()) {
          return origin;
        }
      } catch (_) {}
      return await asset.file;
    }
    return null;
  }

  /// Helper to fetch small thumbnail bytes for fast UI display with memory cache
  Future<Uint8List?> getThumbnail(String assetId, {int size = 200}) async {
    if (_thumbnailCache.containsKey(assetId)) {
      return _thumbnailCache[assetId];
    }
    try {
      final asset = await AssetEntity.fromId(assetId);
      if (asset != null) {
        final data = await asset.thumbnailDataWithSize(
          ThumbnailSize(size, size),
          quality: 80,
        );
        if (data != null) {
          _thumbnailCache[assetId] = data;
        }
        return data;
      }
      // If AssetEntity is not found in PhotoManager memory, load directly from local file
      final item = await _db.getItemByLocalId(assetId);
      if (item?.localFilePath != null) {
        final f = File(item!.localFilePath!);
        if (await f.exists()) {
          final bytes = await f.readAsBytes();
          _thumbnailCache[assetId] = bytes;
          return bytes;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Deletes a photo or video from device storage and removes its record from SQLite
  Future<bool> deleteMediaFromDevice(String assetId) async {
    try {
      final List<String> deletedIds =
          await PhotoManager.editor.deleteWithIds([assetId]);
      final success = deletedIds.contains(assetId);
      await _db.deleteMediaItem(assetId);
      _thumbnailCache.remove(assetId);
      return success;
    } catch (e) {
      debugPrint('Error deleting media from device: $e');
      try {
        final item = await _db.getItemByLocalId(assetId);
        if (item?.localFilePath != null) {
          final f = File(item!.localFilePath!);
          if (await f.exists()) await f.delete();
        }
        await _db.deleteMediaItem(assetId);
        _thumbnailCache.remove(assetId);
        return true;
      } catch (_) {}
      return false;
    }
  }

  /// Scans direct Android storage directories for newly added photos/videos
  /// (e.g. downloaded from Chrome, WhatsApp, or taken when MediaStore hasn't indexed yet)
  Future<List<MediaItem>> scanDirectDirectories() async {
    final discovered = <MediaItem>[];
    if (!Platform.isAndroid) return discovered;

    final targetDirs = [
      '/storage/emulated/0/Download',
      '/storage/emulated/0/DCIM/Camera',
      '/storage/emulated/0/Pictures',
      '/storage/emulated/0/Movies',
    ];

    const imageExtensions = {'.jpg', '.jpeg', '.png', '.webp', '.heic', '.gif'};
    const videoExtensions = {'.mp4', '.mkv', '.mov', '.3gp', '.webm'};

    for (final dirPath in targetDirs) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) continue;

      try {
        await for (final entity in dir.list(recursive: false, followLinks: false)) {
          if (entity is! File) continue;
          final path = entity.path;
          final dotIndex = path.lastIndexOf('.');
          if (dotIndex == -1) continue;
          final ext = path.toLowerCase().substring(dotIndex);
          final isImage = imageExtensions.contains(ext);
          final isVideo = videoExtensions.contains(ext);
          if (!isImage && !isVideo) continue;

          // Check if already in SQLite
          final existing = await _db.getItemByPath(path);
          if (existing != null) continue;

          final stat = await entity.stat();
          final fileName = path.split(RegExp(r'[\\/]')).last;
          final folderName = dirPath.split(RegExp(r'[\\/]')).last;
          final mediaType = isVideo ? AppMediaType.video : AppMediaType.image;
          final mimeType = isVideo ? 'video/mp4' : 'image/jpeg';
          final localId = 'disk_${path.hashCode.abs()}';

          final item = MediaItem(
            localId: localId,
            fileName: fileName,
            mediaType: mediaType,
            mimeType: mimeType,
            fileSize: stat.size,
            createdAt: stat.modified,
            modifiedAt: stat.modified,
            uploadState: UploadState.READY_TO_UPLOAD,
            localFilePath: path,
            folderName: folderName,
          );

          discovered.add(item);
        }
      } catch (e) {
        debugPrint('Direct dir scan error for $dirPath: $e');
      }
    }

    if (discovered.isNotEmpty) {
      await _db.batchUpsertMediaItems(discovered);
      debugPrint('Direct storage scan discovered ${discovered.length} new items!');
    }
    return discovered;
  }

  /// Quickly verifies SQLite items against device storage and cleans up any deleted items
  Future<int> pruneDeletedItems() async {
    try {
      final allItems = await _db.getAllItems(limit: 2000);
      final toDelete = <String>[];
      for (final item in allItems) {
        // If file exists at recorded path, it is definitely NOT deleted!
        if (item.localFilePath != null && item.localFilePath!.isNotEmpty) {
          final f = File(item.localFilePath!);
          if (await f.exists()) continue;
        }

        // Check if it exists at standard device directories
        final possiblePaths = [
          '/storage/emulated/0/DCIM/Camera/${item.fileName}',
          '/storage/emulated/0/DCIM/${item.folderName}/${item.fileName}',
          '/storage/emulated/0/Pictures/${item.folderName}/${item.fileName}',
          '/storage/emulated/0/Download/${item.fileName}',
        ];
        bool existsOnDisk = false;
        for (final p in possiblePaths) {
          if (await File(p).exists()) {
            existsOnDisk = true;
            break;
          }
        }
        if (existsOnDisk) continue;

        // If file is missing from disk AND PhotoManager returns null, only then mark deleted
        final asset = await AssetEntity.fromId(item.localId);
        if (asset == null) {
          toDelete.add(item.localId);
        }
      }
      if (toDelete.isNotEmpty) {
        await _db.deleteMediaItems(toDelete);
      }
      return toDelete.length;
    } catch (_) {
      return 0;
    }
  }
}
