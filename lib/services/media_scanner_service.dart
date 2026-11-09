import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../models/media_item.dart';
import 'database_helper.dart';
import 'device_settings_helper.dart';
import 'settings_repository.dart';

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

  /// Checks whether a given directory or file name represents non-media system junk (thumbnails, app cache, build files).
  /// Deliberately preserves private, locked, hidden (.private, .locked, .secret), and user-secured folders.
  static bool isJunkOrThumbnail(String? name, String? path) {
    final n = (name ?? '').toLowerCase();
    final p = (path ?? '').toLowerCase();

    // 1. Thumbnails
    if (n.contains('thumbnail') ||
        p.contains('.thumbnail') ||
        p.contains('/.thumbnails/') ||
        p.contains('/thumbnails/')) {
      return true;
    }

    // 2. Cache directories
    if (n == 'cache' ||
        n == '.cache' ||
        n.contains('image_cache') ||
        p.contains('/.cache/') ||
        p.contains('/cache/')) {
      return true;
    }

    // 3. App development, git, and system trash
    if (n == '.git' ||
        p.contains('/.git/') ||
        n == '.dart_tool' ||
        p.contains('/.dart_tool/') ||
        n == '.trash' ||
        p.contains('/.trash/') ||
        n == '.recycle' ||
        p.contains('/.recycle/')) {
      return true;
    }

    // 4. Android internal package app caches
    if (p.contains('/android/data/') && (p.contains('/cache') || p.contains('/code_cache'))) {
      return true;
    }

    return false;
  }

  final DatabaseHelper _db = DatabaseHelper.instance;

  final StreamController<ScanProgressReport> _scanProgressController =
      StreamController<ScanProgressReport>.broadcast();
  Stream<ScanProgressReport> get scanProgressStream =>
      _scanProgressController.stream;

  PermissionState _lastPermissionState = PermissionState.notDetermined;
  PermissionState get lastPermissionState => _lastPermissionState;

  final Map<String, Uint8List> _thumbnailCache = {};

  void _putInThumbnailCache(String key, Uint8List bytes) {
    // Keep max 180 thumbnails in memory for fluid scrolling without GC pressure
    if (_thumbnailCache.length >= 180) {
      final firstKey = _thumbnailCache.keys.first;
      _thumbnailCache.remove(firstKey);
    }
    _thumbnailCache[key] = bytes;
  }

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
    Future<void> Function()? onBatchPersisted,
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

    // Step 1: Resilient Multi-Type Album Discovery with retry for MediaStore propagation
    List<AssetPathEntity> albums = [];
    try {
      for (int retry = 0; retry < 3 && albums.isEmpty; retry++) {
        if (retry > 0) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
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
      }
    } catch (e) {
      debugPrint('PhotoManager getAssetPathList error: $e');
    }

    // Step 2: Resilient Fallback - If PhotoManager returned 0 albums (strict OEM, background isolate, or MediaStore propagation)
    // Filter out thumbnail and internal cache albums, preserving locked and private albums
    albums.removeWhere((album) => isJunkOrThumbnail(album.name, null));

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
    recentAlbum ??= albums.isNotEmpty ? albums.first : null;
    if (recentAlbum == null) return [];
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

    // Lightweight set of already uploaded local IDs for instant O(1) incremental skipping without RAM bloat
    final uploadedLocalIds = await _db.getUploadedLocalIdsSet();

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
            // Instant O(1) incremental check: if already uploaded, skip immediately
            if (!forceFullScan && uploadedLocalIds.contains(entity.id)) {
              processedCount++;
              continue;
            }

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

            String mimeType = existingItem?.mimeType ??
                (mediaType == AppMediaType.video ? 'video/mp4' : 'image/jpeg');
            if (existingItem == null) {
              try {
                final m = await entity.mimeTypeAsync;
                if (m != null && m.isNotEmpty) mimeType = m;
              } catch (_) {}
            }

            // Fast file size: reuse already cached DB size or read from MediaStore
            int fileSize = existingItem?.fileSize ?? 0;
            if (fileSize <= 0) {
              try {
                fileSize = await entity.fileSize;
              } catch (_) {}
            }

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

            // Strictly filter out any items from system thumbnail / cache folders
            if (isJunkOrThumbnail(folderName, entity.relativePath)) {
              processedCount++;
              continue;
            }

            if (entity.title != null && isJunkOrThumbnail(entity.title, null)) {
              processedCount++;
              continue;
            }

            String? localFilePath = existingItem?.localFilePath;
            if (localFilePath == null && entity.relativePath != null && entity.title != null) {
              final candidate = '/storage/emulated/0/${entity.relativePath}${entity.title}';
              if (File(candidate).existsSync()) {
                localFilePath = candidate;
              }
            }

            if (localFilePath != null && isJunkOrThumbnail(null, localFilePath)) {
              processedCount++;
              continue;
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
          if (onBatchPersisted != null) {
            try {
              await onBatchPersisted();
            } catch (_) {}
          }
        }

        _scanProgressController.add(ScanProgressReport(
          scannedItems: processedCount,
          totalDiscovered: totalAssetCount,
          currentBatchStatus: 'Indexed $processedCount of $totalAssetCount items...',
        ));
      }
    }

    // Also scan direct storage for private, locked, hidden, and .nomedia folders so they are indexed for silent sync
    try {
      final directDiscovered = await scanDirectDirectories();
      if (directDiscovered.isNotEmpty) {
        discoveredList.addAll(directDiscovered);
        processedCount += directDiscovered.length;
      }
    } catch (e) {
      debugPrint('Direct directory scan error: $e');
    }

    _scanProgressController.add(ScanProgressReport(
      scannedItems: processedCount,
      totalDiscovered: totalAssetCount + (discoveredList.length > totalAssetCount ? discoveredList.length - totalAssetCount : 0),
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

  String? _vthumbDirPath;
  Future<String> _getVthumbDirPath() async {
    if (_vthumbDirPath != null) return _vthumbDirPath!;
    final tmp = await getTemporaryDirectory();
    final d = Directory(p.join(tmp.path, 'vthumbs'));
    if (!d.existsSync()) {
      await d.create(recursive: true);
    }
    _vthumbDirPath = d.path;
    return _vthumbDirPath!;
  }

  /// Synchronously or asynchronously reads pre-extracted video thumbnail file from disk
  Future<File?> getCachedVideoThumbnailFile(String assetId) async {
    try {
      final dirPath = await _getVthumbDirPath();
      final file = File(p.join(dirPath, 'vthumb_${assetId.hashCode.abs()}.jpg'));
      if (file.existsSync() && file.lengthSync() > 0) {
        return file;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveVideoThumbnailToDisk(String assetId, Uint8List bytes) async {
    try {
      final dirPath = await _getVthumbDirPath();
      final file = File(p.join(dirPath, 'vthumb_${assetId.hashCode.abs()}.jpg'));
      await file.writeAsBytes(bytes, flush: false);
    } catch (_) {}
  }

  /// Helper to fetch crisp thumbnail bytes for fast UI display with memory cache
  Future<Uint8List?> getThumbnail(
    String assetId, {
    String? filePath,
    bool isVideo = false,
    int size = 280,
    int quality = 85,
  }) async {
    final cacheKey = '${assetId}_$size';
    if (_thumbnailCache.containsKey(cacheKey)) {
      final cached = _thumbnailCache[cacheKey];
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
      _thumbnailCache.remove(cacheKey);
    }

    // Resolve file path and whether it is a video
    String? resolvedFilePath = filePath;
    MediaItem? dbItem;

    if (resolvedFilePath == null || resolvedFilePath.isEmpty) {
      try {
        dbItem = await _db.getItemByLocalId(assetId);
        resolvedFilePath = dbItem?.localFilePath;
      } catch (_) {}
    }

    final effectiveIsVideo = isVideo || (dbItem?.isVideo ?? false);

    // ==========================================
    // VIDEO THUMBNAIL PIPELINE
    // ==========================================
    if (effectiveIsVideo) {
      // 1. Fast-path: Check persistent disk cache
      final cachedDiskFile = await getCachedVideoThumbnailFile(assetId);
      if (cachedDiskFile != null) {
        try {
          final diskBytes = await cachedDiskFile.readAsBytes();
          if (diskBytes.isNotEmpty) {
            _putInThumbnailCache(cacheKey, diskBytes);
            _putInThumbnailCache(assetId, diskBytes);
            return diskBytes;
          }
        } catch (_) {}
      }

      // 2. Try native hardware-accelerated ThumbnailUtils & MediaMetadataRetriever FIRST.
      // Now that the APK is installed with queued thumbnailExecutor and OPTION_CLOSEST,
      // native decoder handles all file paths (including .nomedia and WhatsApp) with 0 Codec2 errors.
      String? vPath = resolvedFilePath;
      if (vPath == null || vPath.isEmpty) {
        try {
          if (!assetId.startsWith('disk_')) {
            final asset = await AssetEntity.fromId(assetId);
            final f = await asset?.file;
            vPath = f?.path;
          }
        } catch (_) {}
      }

      if (vPath != null && vPath.isNotEmpty) {
        final videoData = await DeviceSettingsHelper.getVideoThumbnail(
          vPath,
          width: 280,
          height: 280,
        );
        if (videoData != null && videoData.isNotEmpty) {
          _saveVideoThumbnailToDisk(assetId, videoData);
          _putInThumbnailCache(cacheKey, videoData);
          _putInThumbnailCache(assetId, videoData);
          return videoData;
        }
      }

      // 3. Fallback for MediaStore videos: PhotoManager standard 200px thumbnail.
      if (!assetId.startsWith('disk_')) {
        try {
          final asset = await AssetEntity.fromId(assetId);
          if (asset != null) {
            final data = await asset.thumbnailDataWithSize(
              const ThumbnailSize.square(200),
              quality: quality,
            );
            if (data != null && data.isNotEmpty) {
              _saveVideoThumbnailToDisk(assetId, data);
              _putInThumbnailCache(cacheKey, data);
              _putInThumbnailCache(assetId, data);
              return data;
            }
          }
        } catch (_) {}
      }

      // 4. Secondary fallback: AssetEntity default thumbnailData
      if (!assetId.startsWith('disk_')) {
        try {
          final asset = await AssetEntity.fromId(assetId);
          final data = await asset?.thumbnailData;
          if (data != null && data.isNotEmpty) {
            _saveVideoThumbnailToDisk(assetId, data);
            _putInThumbnailCache(cacheKey, data);
            _putInThumbnailCache(assetId, data);
            return data;
          }
        } catch (_) {}
      }

      return null;
    }

    // ==========================================
    // PHOTO / IMAGE THUMBNAIL PIPELINE
    // ==========================================
    // 1. Try PhotoManager AssetEntity
    if (!assetId.startsWith('disk_')) {
      try {
        final asset = await AssetEntity.fromId(assetId);
        if (asset != null) {
          final data = await asset.thumbnailDataWithSize(
            ThumbnailSize(size, size),
            quality: quality,
          );
          if (data != null && data.isNotEmpty) {
            _putInThumbnailCache(cacheKey, data);
            _putInThumbnailCache(assetId, data);
            return data;
          }
        }
      } catch (_) {}
    }

    // 2. Direct memory-mapped downsampled decoding for disk photos
    if (resolvedFilePath == null || resolvedFilePath.isEmpty) {
      dbItem ??= await _db.getItemByLocalId(assetId);
      resolvedFilePath = dbItem?.localFilePath;
    }

    if (resolvedFilePath != null && resolvedFilePath.isNotEmpty) {
      final f = File(resolvedFilePath);
      if (await f.exists()) {
        ImmutableBuffer? buffer;
        Codec? codec;
        FrameInfo? frame;
        try {
          // Memory-mapped zero-copy file buffer via C++ OS mmap
          buffer = await ImmutableBuffer.fromFilePath(resolvedFilePath);
          final descriptor = await ImageDescriptor.encoded(buffer);
          // Maintain exact original aspect ratio without distortion or stretching
          final double scale = (descriptor.width > descriptor.height)
              ? size / descriptor.width
              : size / descriptor.height;
          final targetW = (descriptor.width * scale).round().clamp(1, size * 2);
          final targetH = (descriptor.height * scale).round().clamp(1, size * 2);
          codec = await descriptor.instantiateCodec(
            targetWidth: targetW,
            targetHeight: targetH,
          );
          frame = await codec.getNextFrame();
          final byteData =
              await frame.image.toByteData(format: ImageByteFormat.png);
          if (byteData != null) {
            final downsampled = byteData.buffer.asUint8List();
            _putInThumbnailCache(cacheKey, downsampled);
            _putInThumbnailCache(assetId, downsampled);
            return downsampled;
          }
        } catch (_) {
        } finally {
          frame?.image.dispose();
          codec?.dispose();
          buffer?.dispose();
        }
      }
    }

    return null;
  }

  /// Deletes a photo or video from device storage and removes its record from SQLite
  Future<bool> deleteMediaFromDevice(String assetId) async {
    bool fileDeleted = false;

    // 1. Fetch item from database to get file path if available
    final item = await _db.getItemByLocalId(assetId);
    final filePath = item?.localFilePath;

    // 2. Attempt native platform channel deletion (ContentResolver + File.delete)
    try {
      fileDeleted =
          await DeviceSettingsHelper.deleteMediaFileNative(filePath, assetId);
    } catch (_) {}

    // 3. Attempt direct filesystem deletion if file exists
    if (!fileDeleted && filePath != null) {
      try {
        final f = File(filePath);
        if (await f.exists()) {
          await f.delete();
          fileDeleted = true;
        } else {
          fileDeleted = true; // File already deleted from disk
        }
      } catch (_) {}
    }

    // 4. Fallback to PhotoManager editor if it is a valid numeric MediaStore ID
    if (!fileDeleted && !assetId.startsWith('disk_')) {
      try {
        final List<String> deletedIds =
            await PhotoManager.editor.deleteWithIds([assetId]);
        if (deletedIds.contains(assetId)) {
          fileDeleted = true;
        }
      } catch (e) {
        debugPrint('PhotoManager deleteWithIds exception (handled): $e');
      }
    }

    // 5. Always purge from SQLite database and memory caches
    await _db.deleteMediaItem(assetId);
    _removeThumbnailFromCache(assetId);

    // 6. If deletion was blocked by Android 11+ scoped storage, request All Files Access
    if (!fileDeleted && Platform.isAndroid) {
      final hasAllFiles =
          await DeviceSettingsHelper.isAllFilesAccessGranted();
      if (!hasAllFiles) {
        await DeviceSettingsHelper.requestAllFilesAccess();
      }
    }

    return fileDeleted;
  }

  /// Scans direct Android storage directories for newly added photos/videos,
  /// including private, locked, hidden, .nomedia, and vault folders so they are fully accessible for syncing.
  Future<List<MediaItem>> scanDirectDirectories() async {
    final discovered = <MediaItem>[];
    if (!Platform.isAndroid) return discovered;

    // Purge any previously indexed thumbnail items
    try {
      await _db.purgeThumbnailItems();
    } catch (_) {}

    final settings = await SettingsRepository.instance.loadSettings();

    final targetDirs = [
      // Standard Camera, Screenshots & System Media
      '/storage/emulated/0/DCIM/Camera',
      '/storage/emulated/0/DCIM/Screenshots',
      '/storage/emulated/0/DCIM/ScreenRecorder',
      '/storage/emulated/0/DCIM',
      '/storage/emulated/0/Pictures/Screenshots',
      '/storage/emulated/0/Pictures/Download',
      '/storage/emulated/0/Pictures',
      '/storage/emulated/0/Movies/Screenshots',
      '/storage/emulated/0/Movies/ScreenRecorder',
      '/storage/emulated/0/Movies',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Downloads',
      '/storage/emulated/0/Bluetooth',
      '/storage/emulated/0/Documents',

      // Private, Locked & Vault Folders (Android / OEM / User)
      '/storage/emulated/0/Private',
      '/storage/emulated/0/Locked',
      '/storage/emulated/0/Secret',
      '/storage/emulated/0/Vault',
      '/storage/emulated/0/Safe',
      '/storage/emulated/0/.private',
      '/storage/emulated/0/.locked',
      '/storage/emulated/0/.secret',
      '/storage/emulated/0/.hidden',
      '/storage/emulated/0/.vault',
      '/storage/emulated/0/.safe',
      '/storage/emulated/0/.PrivateSafe',
      '/storage/emulated/0/.safebox',
      '/storage/emulated/0/DCIM/.hidden',
      '/storage/emulated/0/DCIM/.private',
      '/storage/emulated/0/DCIM/.locked',
      '/storage/emulated/0/DCIM/Private',
      '/storage/emulated/0/DCIM/Locked',
      '/storage/emulated/0/Pictures/.hidden',
      '/storage/emulated/0/Pictures/.private',
      '/storage/emulated/0/Pictures/.locked',
      '/storage/emulated/0/Pictures/.secret',
      '/storage/emulated/0/Pictures/Private',
      '/storage/emulated/0/Pictures/Locked',
      '/storage/emulated/0/Pictures/Vault',
      '/storage/emulated/0/Pictures/Safe',
      '/storage/emulated/0/Movies/.hidden',
      '/storage/emulated/0/Movies/.private',
      '/storage/emulated/0/Movies/.locked',
      '/storage/emulated/0/Movies/Private',
      '/storage/emulated/0/Movies/Locked',
      '/storage/emulated/0/Download/.private',
      '/storage/emulated/0/Download/.locked',
      '/storage/emulated/0/Download/Private',
      '/storage/emulated/0/Documents/Private',
      '/storage/emulated/0/Documents/Locked',

      // OEM Specific Vault & Hidden Album Paths
      '/storage/emulated/0/MIUI/Gallery/cloud/secretAlbum',
      '/storage/emulated/0/MIUI/secretAlbum',
      '/storage/emulated/0/Tencent/MicroMsg/WeiXin',
      '/storage/emulated/0/.KeepSafe',
      '/storage/emulated/0/.galleryvault',
      '/storage/emulated/0/.calculator',
      '/storage/emulated/0/.calculatorvault',
      '/storage/emulated/0/.lockmypix',

      // WhatsApp & WhatsApp Business (Including Private folders)
      '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images',
      '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/Private',
      '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video',
      '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video/Private',
      '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Images',
      '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Images/Private',
      '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Video',
      '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Video/Private',
      '/storage/emulated/0/WhatsApp/Media/WhatsApp Images',
      '/storage/emulated/0/WhatsApp/Media/WhatsApp Images/Private',
      '/storage/emulated/0/WhatsApp/Media/WhatsApp Video',
      '/storage/emulated/0/WhatsApp/Media/WhatsApp Video/Private',
      '/storage/emulated/0/Pictures/WhatsApp',
      '/storage/emulated/0/Pictures/WhatsApp/Private',

      // Telegram
      '/storage/emulated/0/Telegram/Telegram Images',
      '/storage/emulated/0/Telegram/Telegram Video',
      '/storage/emulated/0/Pictures/Telegram',
      '/storage/emulated/0/Movies/Telegram',
      '/storage/emulated/0/Android/media/org.telegram.messenger/Telegram/Telegram Images',
      '/storage/emulated/0/Android/media/org.telegram.messenger/Telegram/Telegram Video',

      // Social Media (Instagram, Snapchat, Facebook, Messenger, Twitter/X, Reddit, Pinterest, TikTok)
      '/storage/emulated/0/Pictures/Instagram',
      '/storage/emulated/0/DCIM/Instagram',
      '/storage/emulated/0/Pictures/Snapchat',
      '/storage/emulated/0/DCIM/Snapchat',
      '/storage/emulated/0/Pictures/Facebook',
      '/storage/emulated/0/Pictures/Messenger',
      '/storage/emulated/0/Pictures/Twitter',
      '/storage/emulated/0/Pictures/X',
      '/storage/emulated/0/Pictures/Reddit',
      '/storage/emulated/0/Pictures/Pinterest',
      '/storage/emulated/0/Pictures/TikTok',
      '/storage/emulated/0/Movies/TikTok',

      // Photo & Video Editing Apps (Lightroom, Snapseed, Canva, InShot, CapCut, VSCO)
      '/storage/emulated/0/Pictures/Lightroom',
      '/storage/emulated/0/Pictures/AdobeLightroom',
      '/storage/emulated/0/Pictures/Snapseed',
      '/storage/emulated/0/Pictures/Canva',
      '/storage/emulated/0/Pictures/VSCO',
      '/storage/emulated/0/Movies/InShot',
      '/storage/emulated/0/Movies/CapCut',
    ];

    // Add user-configured custom private folder paths
    for (final customPath in settings.customFolderPaths) {
      if (customPath.trim().isNotEmpty) {
        targetDirs.add(customPath.trim());
      }
    }

    // Dynamically discover subdirectories under Pictures, DCIM, Movies, Download, and Documents
    final allDirsToScan = Set<String>.from(targetDirs);
    for (final baseDir in [
      '/storage/emulated/0/Pictures',
      '/storage/emulated/0/DCIM',
      '/storage/emulated/0/Movies',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Documents',
    ]) {
      try {
        final d = Directory(baseDir);
        if (await d.exists()) {
          await for (final sub in d.list(recursive: false, followLinks: false)) {
            if (sub is Directory) {
              final subName = sub.path.split(RegExp(r'[\\/]')).last;
              if (isJunkOrThumbnail(subName, sub.path)) {
                continue;
              }
              allDirsToScan.add(sub.path);
            }
          }
        }
      } catch (_) {}
    }

    const imageExtensions = {'.jpg', '.jpeg', '.png', '.webp', '.heic', '.gif'};
    const videoExtensions = {'.mp4', '.mkv', '.mov', '.3gp', '.webm'};

    // Fast O(1) lightweight set lookups instead of loading heavy objects into memory
    final existingPaths = await _db.getAllLocalFilePathsSet();
    final existingNameSizeKeys = await _db.getAllNameSizeKeysSet();
    final existingFileNamesMap = await _db.getAllFileNamesToLocalIdMap();

    for (final dirPath in allDirsToScan) {
      if (isJunkOrThumbnail(null, dirPath)) {
        continue;
      }

      final dir = Directory(dirPath);
      if (!await dir.exists()) continue;

      // Note: We deliberately DO NOT skip folders containing .nomedia!
      // In Android, .nomedia is standard for private/locked folders. We scan them so they are synced.

      try {
        await for (final entity in dir.list(recursive: false, followLinks: false)) {
          if (entity is! File) continue;
          final path = entity.path;
          if (isJunkOrThumbnail(null, path)) {
            continue;
          }
          if (existingPaths.contains(path)) continue;

          final dotIndex = path.lastIndexOf('.');
          if (dotIndex == -1) continue;
          final ext = path.toLowerCase().substring(dotIndex);
          final isImage = imageExtensions.contains(ext);
          final isVideo = videoExtensions.contains(ext);
          if (!isImage && !isVideo) continue;

          final stat = await entity.stat();
          final fileName = path.split(RegExp(r'[\\/]')).last;
          final nameSizeKey = '${fileName}_${stat.size}';

          // Zero-duplication guarantee: check if file is already indexed in SQLite
          if (existingFileNamesMap.containsKey(fileName) ||
              existingNameSizeKeys.contains(nameSizeKey) ||
              existingPaths.contains(path)) {
            final existingId = existingFileNamesMap[fileName];
            if (existingId != null) {
              await _db.updateLocalFilePath(existingId, path);
            }
            continue;
          }

          existingPaths.add(path);
          existingNameSizeKeys.add(nameSizeKey);
          existingFileNamesMap[fileName] = 'disk_${path.hashCode.abs()}';
          var folderName = dirPath.split(RegExp(r'[\\/]')).last;
          
          if (dirPath.contains('WhatsApp') && folderName.toLowerCase() == 'private') {
            folderName = 'WhatsApp Private';
          } else if (folderName == 'DCIM') {
            folderName = 'Camera';
          } else if (folderName == 'Downloads') {
            folderName = 'Download';
          } else if (folderName.startsWith('.')) {
            final clean = folderName.replaceFirst(RegExp(r'^\.+'), '');
            final cLower = clean.toLowerCase();
            if (cLower == 'private') {
              folderName = 'Private (Locked)';
            } else if (cLower == 'locked') {
              folderName = 'Locked Folder';
            } else if (cLower == 'secret') {
              folderName = 'Secret Folder';
            } else if (cLower == 'privatesafe') {
              folderName = 'Private Safe';
            } else if (cLower == 'hidden') {
              folderName = 'Hidden (Locked)';
            } else if (clean.isNotEmpty) {
              folderName = '$clean (Locked)';
            }
          } else if (folderName.toLowerCase() == 'secretalbum') {
            folderName = 'Private Album';
          }

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
            toDelete.add(item.localId);
            continue;
          } else {
            // File confirmed to exist on disk
            continue;
          }
        }

        // C. PhotoManager assets
        if (albums.isNotEmpty) {
          if (!validAssetIds.contains(item.localId)) {
            // Asset is not in any active album, verify if actually deleted
            try {
              final asset = await AssetEntity.fromId(item.localId);
              if (asset == null || !await asset.exists) {
                toDelete.add(item.localId);
              }
            } catch (_) {
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
