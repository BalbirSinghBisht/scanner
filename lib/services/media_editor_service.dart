import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/media_item.dart';
import 'database_helper.dart';

class MediaEditorService {
  static final MediaEditorService instance = MediaEditorService._init();
  MediaEditorService._init();

  static const MethodChannel _channel =
      MethodChannel('com.mediabackup.scanner/device_settings');

  /// Resolves the device's DCIM directory path across Android, iOS, and fallbacks
  Future<Directory> getDcimDirectory() async {
    if (Platform.isAndroid) {
      const androidDcim = '/storage/emulated/0/DCIM';
      final dir = Directory(androidDcim);
      if (await dir.exists()) {
        return dir;
      }
      try {
        await dir.create(recursive: true);
        return dir;
      } catch (_) {}
    }

    // iOS / macOS / Desktop / Sandbox fallback
    final appDir = await getApplicationDocumentsDirectory();
    final dcimDir = Directory(p.join(appDir.path, 'DCIM'));
    if (!await dcimDir.exists()) {
      await dcimDir.create(recursive: true);
    }
    return dcimDir;
  }

  /// Triggers OS media scanner to index newly saved file into system MediaStore
  Future<void> _notifyMediaScanner(String filePath, String mimeType) async {
    try {
      await _channel.invokeMethod('scanMediaFile', {
        'path': filePath,
        'mimeType': mimeType,
      });
    } catch (_) {}
  }

  /// Saves edited image directly to the DCIM folder and registers it in SQLite
  Future<MediaItem?> saveEditedImage({
    required Uint8List bytes,
    required String originalFileName,
    String? originalLocalId,
  }) async {
    try {
      final now = DateTime.now();
      final baseName = p.basenameWithoutExtension(originalFileName);
      final newTitle = '${baseName}_edited_${now.millisecondsSinceEpoch}.jpg';

      // 1. Resolve DCIM Directory and write file directly into DCIM
      final dcimDir = await getDcimDirectory();
      final diskFile = File(p.join(dcimDir.path, newTitle));
      await diskFile.writeAsBytes(bytes);

      // 2. Save to system gallery via PhotoManager with relativePath = 'DCIM'
      AssetEntity? asset;
      try {
        asset = await PhotoManager.editor.saveImage(
          bytes,
          title: newTitle,
          filename: newTitle,
          relativePath: 'DCIM',
        );
      } catch (_) {}

      // 3. Inform Android MediaScanner so file is indexed into DCIM gallery
      await _notifyMediaScanner(diskFile.path, 'image/jpeg');

      String localId = asset?.id ?? 'edited_${now.millisecondsSinceEpoch}';
      String filePath = diskFile.path;

      if (asset != null) {
        try {
          final f = await asset.file;
          if (f != null && await f.exists()) {
            filePath = f.path;
          }
        } catch (_) {}
      }

      final mediaItem = MediaItem(
        localId: localId,
        fileName: newTitle,
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: bytes.length,
        createdAt: now,
        modifiedAt: now,
        uploadState: UploadState.READY_TO_UPLOAD,
        localFilePath: filePath,
        folderName: 'DCIM',
      );

      await DatabaseHelper.instance.upsertMediaItem(mediaItem);
      return mediaItem;
    } catch (e) {
      return null;
    }
  }

  /// Trims video and saves the output directly to the DCIM folder
  Future<MediaItem?> trimAndSaveVideo({
    required String sourceFilePath,
    required int startMs,
    required int endMs,
    required bool muteAudio,
    required String originalFileName,
  }) async {
    try {
      final now = DateTime.now();
      final baseName = p.basenameWithoutExtension(originalFileName);
      final newTitle = '${baseName}_trimmed_${now.millisecondsSinceEpoch}.mp4';

      // 1. Target output directly in the DCIM directory
      final dcimDir = await getDcimDirectory();
      final outputPath = p.join(dcimDir.path, newTitle);

      final res = await _channel.invokeMethod<String>('trimVideo', {
        'inputPath': sourceFilePath,
        'outputPath': outputPath,
        'startMs': startMs.toDouble(),
        'endMs': endMs.toDouble(),
        'muteAudio': muteAudio,
      });

      if (res == null) return null;
      final outputFile = File(outputPath);
      if (!await outputFile.exists()) return null;

      final fileSize = await outputFile.length();
      final durationSec = ((endMs - startMs) / 1000).round();

      // 2. Save video to system gallery with relativePath = 'DCIM'
      AssetEntity? asset;
      try {
        asset = await PhotoManager.editor.saveVideo(
          outputFile,
          title: newTitle,
          relativePath: 'DCIM',
        );
      } catch (_) {}

      // 3. Notify MediaScanner
      await _notifyMediaScanner(outputFile.path, 'video/mp4');

      String localId = asset?.id ?? 'trimmed_${now.millisecondsSinceEpoch}';
      String finalPath = outputFile.path;

      if (asset != null) {
        try {
          final f = await asset.file;
          if (f != null && await f.exists()) {
            finalPath = f.path;
          }
        } catch (_) {}
      }

      final mediaItem = MediaItem(
        localId: localId,
        fileName: newTitle,
        mediaType: AppMediaType.video,
        mimeType: 'video/mp4',
        fileSize: fileSize,
        durationSeconds: durationSec > 0 ? durationSec : 1,
        createdAt: now,
        modifiedAt: now,
        uploadState: UploadState.READY_TO_UPLOAD,
        localFilePath: finalPath,
        folderName: 'DCIM',
      );

      await DatabaseHelper.instance.upsertMediaItem(mediaItem);
      return mediaItem;
    } catch (e) {
      return null;
    }
  }

  /// Extracts frames and converts a video segment into an animated GIF, saving directly to DCIM
  Future<MediaItem?> exportVideoAsGif({
    required String sourceFilePath,
    required int startMs,
    required int endMs,
    required String originalFileName,
    int maxFrames = 12,
  }) async {
    try {
      final now = DateTime.now();
      final baseName = p.basenameWithoutExtension(originalFileName);
      final newTitle = '${baseName}_anim_${now.millisecondsSinceEpoch}.gif';

      // 1. Extract sampled frames from video
      final rawFrames = await _channel.invokeMethod<List<dynamic>>('extractVideoFrames', {
        'inputPath': sourceFilePath,
        'startMs': startMs.toDouble(),
        'endMs': endMs.toDouble(),
        'maxFrames': maxFrames,
      });

      if (rawFrames == null || rawFrames.isEmpty) return null;

      // 2. Encode to animated GIF using image package
      final encoder = img.GifEncoder(delay: 10, repeat: 0);
      for (final f in rawFrames) {
        final frameBytes = f as Uint8List;
        final decoded = img.decodeImage(frameBytes);
        if (decoded != null) {
          encoder.addFrame(decoded);
        }
      }

      final gifBytes = encoder.finish();
      if (gifBytes == null || gifBytes.isEmpty) return null;

      // 3. Save directly to DCIM folder
      final dcimDir = await getDcimDirectory();
      final diskFile = File(p.join(dcimDir.path, newTitle));
      await diskFile.writeAsBytes(gifBytes);

      // 4. Save to gallery via PhotoManager
      AssetEntity? asset;
      try {
        asset = await PhotoManager.editor.saveImage(
          gifBytes,
          title: newTitle,
          filename: newTitle,
          relativePath: 'DCIM',
        );
      } catch (_) {}

      // 5. Notify MediaScanner
      await _notifyMediaScanner(diskFile.path, 'image/gif');

      String localId = asset?.id ?? 'gif_${now.millisecondsSinceEpoch}';
      String filePath = diskFile.path;

      final mediaItem = MediaItem(
        localId: localId,
        fileName: newTitle,
        mediaType: AppMediaType.image,
        mimeType: 'image/gif',
        fileSize: gifBytes.length,
        createdAt: now,
        modifiedAt: now,
        uploadState: UploadState.READY_TO_UPLOAD,
        localFilePath: filePath,
        folderName: 'DCIM',
      );

      await DatabaseHelper.instance.upsertMediaItem(mediaItem);
      return mediaItem;
    } catch (e) {
      return null;
    }
  }
}
