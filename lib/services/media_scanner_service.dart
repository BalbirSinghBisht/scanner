import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../models/media_item.dart';
import 'database_helper.dart';

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

  bool get isPermissionGranted =>
      _lastPermissionState == PermissionState.authorized ||
      _lastPermissionState == PermissionState.limited;

  bool get isPartialAccess => _lastPermissionState == PermissionState.limited;

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

  /// Opens the device system settings for this app
  Future<void> openSettings() async {
    await PhotoManager.openSetting();
  }

  /// Scans device media library incrementally using pagination.
  /// Does NOT load heavy full-resolution image/video bytes into RAM.
  Future<List<MediaItem>> scanMedia({
    bool forceFullScan = false,
    DateTime? scanSince,
  }) async {
    final perm = await requestPermission();
    if (perm == PermissionState.denied || perm == PermissionState.restricted) {
      throw MediaPermissionDeniedException(
        'Media library permission was denied by the user.',
        isPermanentlyDenied: false,
      );
    }

    // Retrieve album collections (Recent / All Photos and Videos)
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.common, // Both images and videos
      hasAll: true,
      onlyAll: true,
    );

    if (albums.isEmpty) {
      _scanProgressController.add(const ScanProgressReport(
        scannedItems: 0,
        totalDiscovered: 0,
        currentBatchStatus: 'No media albums found on device',
        isCompleted: true,
      ));
      return [];
    }

    final recentAlbum = albums.first;
    final totalAssetCount = await recentAlbum.assetCountAsync;

    _scanProgressController.add(ScanProgressReport(
      scannedItems: 0,
      totalDiscovered: totalAssetCount,
      currentBatchStatus: 'Found $totalAssetCount accessible media items. Beginning metadata indexing...',
    ));

    final discoveredList = <MediaItem>[];
    const pageSize = AppConstants.scanPageSize;
    final totalPages = (totalAssetCount / pageSize).ceil();

    int processedCount = 0;

    for (int page = 0; page < totalPages; page++) {
      final List<AssetEntity> entities = await recentAlbum.getAssetListPaged(
        page: page,
        size: pageSize,
      );

      final batchItems = <MediaItem>[];

      for (final entity in entities) {
        // Incremental check: if scanSince is set and item created before it, skip if not forceFullScan
        if (!forceFullScan && scanSince != null) {
          if (entity.createDateTime.isBefore(scanSince)) {
            // Already indexed in previous scans
            continue;
          }
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

        // Check if item already exists in local SQLite manifest
        final existingItem = await _db.getItemByLocalId(entity.id);

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
      return await asset.file;
    }
    return null;
  }

  /// Helper to fetch small thumbnail bytes for fast UI display
  Future<Uint8List?> getThumbnail(String assetId, {int size = 200}) async {
    try {
      final asset = await AssetEntity.fromId(assetId);
      if (asset != null) {
        return await asset.thumbnailDataWithSize(
          ThumbnailSize(size, size),
          quality: 80,
        );
      }
    } catch (_) {}
    return null;
  }
}
