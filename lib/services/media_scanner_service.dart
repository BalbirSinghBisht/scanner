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

  /// Synchronously returns cached thumbnail bytes if already loaded in memory.
  /// If [size] is specified, it first checks for that exact size, falling back to any cached resolution.
  Uint8List? getCachedThumbnail(String assetId, {int? size}) {
    if (size != null) {
      final sizedKey = '${assetId}_$size';
      final sizedBytes = _thumbnailCache[sizedKey];
      if (sizedBytes != null && sizedBytes.isNotEmpty) {
        return sizedBytes;
      }
    }
    return _thumbnailCache[assetId];
  }

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
      if (state == PermissionState.authorized ||
          state == PermissionState.limited ||
          _lastPermissionState == PermissionState.notDetermined) {
        _lastPermissionState = state;
      }
      return state;
    } catch (e) {
      debugPrint('Error requesting media permissions: $e');
      return _lastPermissionState;
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
      var albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: true,
        onlyAll: false,
      );
      if (albums.isEmpty) {
        albums = await PhotoManager.getAssetPathList(
          type: RequestType.all,
          hasAll: true,
          onlyAll: false,
        );
      }
      if (albums.isEmpty) {
        final img = await PhotoManager.getAssetPathList(
          type: RequestType.image,
          hasAll: true,
          onlyAll: false,
        );
        final vid = await PhotoManager.getAssetPathList(
          type: RequestType.video,
          hasAll: true,
          onlyAll: false,
        );
        albums = [...img, ...vid];
      }
      return albums;
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
        final existing = await _db.getAllItems(limit: 500);
        if (existing.isNotEmpty) {
          debugPrint('Permissions denied, but serving ${existing.length} cached items');
          return existing;
        }
        throw MediaPermissionDeniedException(
          'Media library permission was denied by the user.',
          isPermanentlyDenied: false,
        );
      }
    }

    // Step 1: Resilient Multi-Type Album Discovery (never rely on synthetic "onlyAll: true" alone)
    List<AssetPathEntity> albums = [];
    try {
      albums = await PhotoManager.getAssetPathList(
        type: RequestType.common, // Images and videos
        hasAll: true,
        onlyAll: false,
      );

      if (albums.isEmpty) {
        albums = await PhotoManager.getAssetPathList(
          type: RequestType.all,
          hasAll: true,
          onlyAll: false,
        );
      }

      if (albums.isEmpty) {
        final img = await PhotoManager.getAssetPathList(
          type: RequestType.image,
          hasAll: true,
          onlyAll: false,
        );
        final vid = await PhotoManager.getAssetPathList(
          type: RequestType.video,
          hasAll: true,
          onlyAll: false,
        );
        albums = [...img, ...vid];
      }
    } catch (e) {
      debugPrint('PhotoManager getAssetPathList error: $e');
    }

    // Step 2: Resilient Fallback - If PhotoManager returned 0 albums (strict OEM, background isolate, or MediaStore propagation)
    if (albums.isEmpty) {
      debugPrint('No albums from PhotoManager. Falling back to direct storage scan and SQLite cache...');
      final directItems = await scanDirectDirectories();
      if (directItems.isNotEmpty) {
        _scanProgressController.add(ScanProgressReport(
          scannedItems: directItems.length,
          totalDiscovered: directItems.length,
          currentBatchStatus: 'Found ${directItems.length} media items via device storage.',
          isCompleted: true,
        ));
        return directItems;
      }

      final existingDbItems = await _db.getAllItems(limit: 500);
      if (existingDbItems.isNotEmpty) {
        _scanProgressController.add(ScanProgressReport(
          scannedItems: existingDbItems.length,
          totalDiscovered: existingDbItems.length,
          currentBatchStatus: 'Retained ${existingDbItems.length} media items from device database.',
          isCompleted: true,
        ));
        return existingDbItems;
      }

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
      currentBatchStatus: 'Found $totalAssetCount accessible media items. Indexing metadata...',
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
          try {
            // Fast incremental check: if already indexed and uploaded, skip immediately
            final existingItem = await _db.getItemByLocalId(entity.id);
            if (!forceFullScan &&
                existingItem != null &&
                existingItem.uploadState == UploadState.UPLOADED) {
              processedCount++;
              continue;
            }

            final mediaType = entity.type == AssetType.video
                ? AppMediaType.video
                : AppMediaType.image;

            String mimeType = mediaType == AppMediaType.video ? 'video/mp4' : 'image/jpeg';
            try {
              final m = await entity.mimeTypeAsync;
              if (m != null && m.isNotEmpty) mimeType = m;
            } catch (_) {}

            // Fast native file size directly from OS MediaStore without copying heavy files into cache
            int fileSize = 0;
            try {
              fileSize = await entity.fileSize;
            } catch (_) {}

            // Extract folder name accurately without triggering disk IO
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
              if (!album.isAll && album.name.isNotEmpty) {
                folderName = album.name;
              }
            }

            if (folderName?.toUpperCase() == 'DCIM') {
              folderName = 'Camera';
            }
            folderName ??= (mediaType == AppMediaType.video ? 'Videos' : 'Camera');

            String? localFilePath = existingItem?.localFilePath;
            if (localFilePath == null && entity.relativePath != null && entity.title != null) {
              final candidate = '/storage/emulated/0/${entity.relativePath}${entity.title}';
              if (File(candidate).existsSync()) {
                localFilePath = candidate;
              }
            }

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
              localFilePath: localFilePath,
              folderName: folderName,
            );

            batchItems.add(item);
            discoveredList.add(item);
            processedCount++;
          } catch (e) {
            debugPrint('Skipping entity ${entity.id} due to parse error (possibly deleted): $e');
          }
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

  /// Helper to get direct File instance for an AssetEntity ID when ready to upload or hash.
  /// Falls back to direct device paths and local manifest path if PhotoManager asset lookup is restricted.
  Future<File?> getMediaFile(String assetId) async {
    try {
      final asset = await AssetEntity.fromId(assetId);
      if (asset != null) {
        try {
          final origin = await asset.originFile;
          if (origin != null && await origin.exists()) {
            return origin;
          }
        } catch (_) {}
        final f = await asset.file;
        if (f != null && await f.exists()) {
          return f;
        }
      }
    } catch (_) {}

    // Resilient fallback: lookup in SQLite database and check filesystem
    try {
      final item = await _db.getItemByLocalId(assetId);
      if (item != null) {
        if (item.localFilePath != null && item.localFilePath!.isNotEmpty) {
          final f = File(item.localFilePath!);
          if (await f.exists()) return f;
        }

        if (Platform.isAndroid) {
          final candidates = [
            '/storage/emulated/0/DCIM/Camera/${item.fileName}',
            '/storage/emulated/0/DCIM/${item.folderName}/${item.fileName}',
            '/storage/emulated/0/Pictures/${item.folderName}/${item.fileName}',
            '/storage/emulated/0/Movies/${item.folderName}/${item.fileName}',
            '/storage/emulated/0/Download/${item.fileName}',
          ];
          for (final p in candidates) {
            final f = File(p);
            if (await f.exists()) return f;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  void _removeThumbnailFromCache(String assetId) {
    _thumbnailCache.remove(assetId);
    _thumbnailCache.removeWhere((k, _) => k.startsWith('${assetId}_'));
  }

  /// Invalidates thumbnail cache for a specific asset or all assets
  void invalidateCache([String? assetId]) {
    if (assetId != null) {
      _removeThumbnailFromCache(assetId);
    } else {
      _thumbnailCache.clear();
    }
  }

  /// Helper to fetch crisp thumbnail bytes for fast UI display with memory cache
  Future<Uint8List?> getThumbnail(
    String assetId, {
    int size = 500,
    int quality = 95,
  }) async {
    final cacheKey = '${assetId}_$size';
    if (_thumbnailCache.containsKey(cacheKey)) {
      final cached = _thumbnailCache[cacheKey];
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
      _thumbnailCache.remove(cacheKey);
    }
    try {
      final asset = await AssetEntity.fromId(assetId);
      if (asset != null) {
        final data = await asset.thumbnailDataWithSize(
          ThumbnailSize(size, size),
          quality: quality,
        );
        if (data != null && data.isNotEmpty) {
          _thumbnailCache[cacheKey] = data;
          _thumbnailCache[assetId] = data;
          return data;
        }
      }
      final item = await _db.getItemByLocalId(assetId);
      if (item?.localFilePath != null) {
        final f = File(item!.localFilePath!);
        if (await f.exists()) {
          final bytes = await f.readAsBytes();
          if (bytes.isNotEmpty) {
            _thumbnailCache[cacheKey] = bytes;
            _thumbnailCache[assetId] = bytes;
            return bytes;
          }
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
      _removeThumbnailFromCache(assetId);
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
        _removeThumbnailFromCache(assetId);
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
      '/storage/emulated/0/Downloads',
      '/storage/emulated/0/DCIM/Camera',
      '/storage/emulated/0/DCIM',
      '/storage/emulated/0/Pictures',
      '/storage/emulated/0/Pictures/Download',
      '/storage/emulated/0/Pictures/Screenshots',
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

          final existing = await _db.getItemByPath(path);
          if (existing != null) continue;

          final stat = await entity.stat();
          final fileName = path.split(RegExp(r'[\\/]')).last;
          var folderName = dirPath.split(RegExp(r'[\\/]')).last;
          if (folderName == 'DCIM') folderName = 'Camera';
          if (folderName == 'Downloads') folderName = 'Download';

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

  /// Verifies SQLite items against device storage and cleans up any truly deleted items.
  /// Reliably detects when albums or files have been deleted from external file managers or galleries.
  Future<int> pruneDeletedItems() async {
    try {
      // Guardrail 1: Only prune if permissions are explicitly authorized
      if (!isPermissionGranted) {
        debugPrint('Skipping pruneDeletedItems: permissions not authorized');
        return 0;
      }

      final allItems = await _db.getAllItems(limit: 5000);
      if (allItems.isEmpty) return 0;

      final toDelete = <String>{};

      // 1. Check folder-level deletions:
      // If a custom album directory was completely deleted from disk by another file manager,
      // mark all items belonging to that folder for removal.
      if (Platform.isAndroid) {
        final distinctFolders = <String>{};
        for (final item in allItems) {
          if (item.folderName != null && item.folderName!.trim().isNotEmpty) {
            final f = item.folderName!.trim();
            final fLower = f.toLowerCase();
            if (fLower != 'camera' &&
                fLower != 'videos' &&
                fLower != 'all photos & videos' &&
                fLower != 'download' &&
                fLower != 'downloads') {
              distinctFolders.add(f);
            }
          }
        }

        for (final folder in distinctFolders) {
          final candidates = [
            Directory('/storage/emulated/0/DCIM/$folder'),
            Directory('/storage/emulated/0/Pictures/$folder'),
            Directory('/storage/emulated/0/Movies/$folder'),
            Directory('/storage/emulated/0/Download/$folder'),
            Directory('/storage/emulated/0/$folder'),
          ];
          bool anyDirExists = false;
          for (final dir in candidates) {
            if (dir.existsSync()) {
              anyDirExists = true;
              break;
            }
          }

          if (!anyDirExists) {
            // Check if any items in this folder have a surviving localFilePath on disk
            bool anyFileExistsInFolder = false;
            final folderItems = allItems.where((it) => it.folderName == folder);
            for (final it in folderItems) {
              if (it.localFilePath != null && File(it.localFilePath!).existsSync()) {
                anyFileExistsInFolder = true;
                break;
              }
            }
            if (!anyFileExistsInFolder) {
              // The entire album folder was deleted from device storage!
              debugPrint('Album folder deleted from device storage: $folder');
              for (final it in folderItems) {
                toDelete.add(it.localId);
              }
            }
          }
        }
      }

      // 2. Query valid albums and asset IDs from PhotoManager
      final albums = await getAllAlbums();
      final validAssetIds = <String>{};
      for (final album in albums) {
        final count = await album.assetCountAsync;
        if (count > 0) {
          final entities = await album.getAssetListRange(
            start: 0,
            end: count.clamp(0, 10000),
          );
          for (final e in entities) {
            validAssetIds.add(e.id);
          }
          if (album.isAll) break;
        }
      }

      // 3. Check individual items
      for (final item in allItems) {
        if (toDelete.contains(item.localId)) continue;

        // A. Direct storage files (disk_...)
        if (item.localId.startsWith('disk_')) {
          if (item.localFilePath == null || !File(item.localFilePath!).existsSync()) {
            toDelete.add(item.localId);
          }
          continue;
        }

        // B. Item with known localFilePath
        if (item.localFilePath != null && item.localFilePath!.isNotEmpty) {
          final file = File(item.localFilePath!);
          if (!file.existsSync()) {
            // File not found at recorded path; verify if it exists anywhere or via PhotoManager
            final alt = await getMediaFile(item.localId);
            if (alt == null || !await alt.exists()) {
              toDelete.add(item.localId);
              continue;
            } else {
              await _db.updateLocalFilePath(item.localId, alt.path);
            }
          } else {
            // File confirmed to exist on disk
            continue;
          }
        }

        // C. PhotoManager assets
        if (albums.isNotEmpty) {
          if (!validAssetIds.contains(item.localId)) {
            // Asset is not in any active album
            final f = await getMediaFile(item.localId);
            if (f == null || !await f.exists()) {
              toDelete.add(item.localId);
            }
          } else {
            // In validAssetIds, but verify underlying file still exists (MediaStore can be stale)
            try {
              final asset = await AssetEntity.fromId(item.localId);
              if (asset == null) {
                toDelete.add(item.localId);
              } else {
                final exists = await asset.exists;
                if (!exists) {
                  toDelete.add(item.localId);
                } else {
                  final f = await asset.originFile ?? await asset.file;
                  if (f == null || !await f.exists()) {
                    toDelete.add(item.localId);
                  } else {
                    await _db.updateLocalFilePath(item.localId, f.path);
                  }
                }
              }
            } catch (_) {
              // PhotoManager throws PlatformException when underlying file was deleted
              toDelete.add(item.localId);
            }
          }
        }
      }

      if (toDelete.isNotEmpty) {
        debugPrint('Safely pruned ${toDelete.length} confirmed deleted items from database');
        for (final id in toDelete) {
          _removeThumbnailFromCache(id);
        }
        await _db.deleteMediaItems(toDelete.toList());
      }
      return toDelete.length;
    } catch (e) {
      debugPrint('Error during pruneDeletedItems: $e');
      return 0;
    }
  }
}
