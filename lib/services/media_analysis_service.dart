import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../core/constants/app_constants.dart';
import '../models/duplicate_group.dart';
import '../models/media_item.dart';
import 'database_helper.dart';
import 'media_scanner_service.dart';

class AnalysisReport {
  final int totalPhotos;
  final int totalVideos;
  final int totalSizeBytes;
  final List<MediaItem> largeFiles;
  final List<DuplicateGroup> duplicateGroups;
  final Map<String, int> mimeDistribution;
  final Map<String, int> monthlyDistribution;

  const AnalysisReport({
    required this.totalPhotos,
    required this.totalVideos,
    required this.totalSizeBytes,
    required this.largeFiles,
    required this.duplicateGroups,
    required this.mimeDistribution,
    required this.monthlyDistribution,
  });
}

class MediaAnalysisService {
  static final MediaAnalysisService instance = MediaAnalysisService._init();
  MediaAnalysisService._init();

  final DatabaseHelper _db = DatabaseHelper.instance;
  final MediaScannerService _scanner = MediaScannerService.instance;

  /// Computes SHA-256 hash for a file using streamed 64KB chunks.
  /// Prevents loading large video files into memory.
  Future<String?> computeFileHash(File file) async {
    try {
      if (!await file.exists()) return null;
      final digest = await sha256.bind(file.openRead()).first;
      return digest.toString();
    } catch (e) {
      return null;
    }
  }

  /// Ensures a MediaItem has its content_hash computed and saved in manifest
  Future<String?> ensureItemHash(MediaItem item) async {
    if (item.contentHash != null && item.contentHash!.isNotEmpty) {
      return item.contentHash;
    }

    File? file;
    if (item.localFilePath != null) {
      final f = File(item.localFilePath!);
      if (await f.exists()) file = f;
    }
    file ??= await _scanner.getMediaFile(item.localId);

    if (file != null) {
      final hash = await computeFileHash(file);
      if (hash != null) {
        await _db.updateContentHash(item.localId, hash);
        return hash;
      }
    }
    return null;
  }

  /// Runs comprehensive local media analysis over indexed items in the manifest
  Future<AnalysisReport> runAnalysis({
    int largeFileThresholdBytes = AppConstants.defaultLargeFileThresholdBytes,
  }) async {
    final allItems = await _db.getAllItems(limit: 10000);

    int photosCount = 0;
    int videosCount = 0;
    int totalBytes = 0;
    final mimeMap = <String, int>{};
    final monthMap = <String, int>{};
    final largeFiles = <MediaItem>[];

    for (final item in allItems) {
      if (item.mediaType == AppMediaType.video) {
        videosCount++;
      } else {
        photosCount++;
      }

      totalBytes += item.fileSize;

      // MIME breakdown
      mimeMap[item.mimeType] = (mimeMap[item.mimeType] ?? 0) + 1;

      // Monthly breakdown (e.g. "2026-01")
      final monthKey =
          '${item.createdAt.year}-${item.createdAt.month.toString().padLeft(2, '0')}';
      monthMap[monthKey] = (monthMap[monthKey] ?? 0) + 1;

      // Large files detection
      if (item.fileSize >= largeFileThresholdBytes) {
        largeFiles.add(item);
      }
    }

    // Sort large files descending by size
    largeFiles.sort((a, b) => b.fileSize.compareTo(a.fileSize));

    // Duplicate detection
    final rawGroups = await _db.getDuplicateGroups();
    final duplicateGroups = <DuplicateGroup>[];

    for (final group in rawGroups) {
      if (group.length > 1) {
        final sig = group.first.contentHash ??
            '${group.first.fileSize}_${group.first.width}x${group.first.height}';
        duplicateGroups.add(DuplicateGroup(
          signature: sig,
          items: group,
        ));
      }
    }

    return AnalysisReport(
      totalPhotos: photosCount,
      totalVideos: videosCount,
      totalSizeBytes: totalBytes,
      largeFiles: largeFiles,
      duplicateGroups: duplicateGroups,
      mimeDistribution: mimeMap,
      monthlyDistribution: monthMap,
    );
  }
}
