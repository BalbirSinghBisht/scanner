import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../models/media_item.dart';
import 'auth_service.dart';

typedef UploadProgressCallback = void Function(int bytesUploaded, int totalBytes);

/// Custom Stream wrapper that reports byte progress as chunks are sent to HTTP socket
class ProgressCountingStream extends Stream<List<int>> {
  final Stream<List<int>> _source;
  final int _totalBytes;
  final UploadProgressCallback _onProgress;
  int _bytesSent = 0;

  ProgressCountingStream(this._source, this._totalBytes, this._onProgress);

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _source.listen(
      (chunk) {
        _bytesSent += chunk.length;
        _onProgress(_bytesSent, _totalBytes);
        if (onData != null) onData(chunk);
      },
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class GoogleDriveService {
  static final GoogleDriveService instance = GoogleDriveService._init();
  GoogleDriveService._init();

  final AuthService _auth = AuthService.instance;

  // In-memory folder path cache: e.g. "PhoneBackup/Photos/2026/01" -> "driveFolderId"
  final Map<String, String> _folderCache = {};

  drive.DriveApi? _driveApi;

  Future<drive.DriveApi> _getDriveApi() async {
    final client = await _auth.getAuthenticatedClient();
    _driveApi = drive.DriveApi(client);
    return _driveApi!;
  }

  /// Resolves or recursively creates folder hierarchy in Google Drive
  /// e.g. ['PhoneBackup', 'Photos', '2026', '01']
  Future<String> getOrCreateFolderPath(List<String> pathSegments) async {
    final fullPath = pathSegments.join('/');
    if (_folderCache.containsKey(fullPath)) {
      return _folderCache[fullPath]!;
    }

    final api = await _getDriveApi();
    String currentParentId = 'root';
    final currentAccumulatedPath = <String>[];

    for (final segment in pathSegments) {
      currentAccumulatedPath.add(segment);
      final partialPath = currentAccumulatedPath.join('/');

      if (_folderCache.containsKey(partialPath)) {
        currentParentId = _folderCache[partialPath]!;
        continue;
      }

      // Check if folder already exists in Drive under currentParentId
      final escapedSegment = segment.replaceAll("'", "\\'");
      final query =
          "name = '$escapedSegment' and "
          "mimeType = 'application/vnd.google-apps.folder' and "
          "'$currentParentId' in parents and "
          "trashed = false";

      final fileList = await api.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      String folderId;
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        folderId = fileList.files!.first.id!;
      } else {
        // Create new folder
        final folderMetadata = drive.File()
          ..name = segment
          ..mimeType = 'application/vnd.google-apps.folder'
          ..parents = [currentParentId];

        final created = await api.files.create(
          folderMetadata,
          $fields: 'id, name',
        );
        folderId = created.id!;
      }

      _folderCache[partialPath] = folderId;
      currentParentId = folderId;
    }

    return currentParentId;
  }

  /// Checks if file already exists in target folder by name and size to avoid duplicate uploads
  Future<String?> findExistingDriveFile({
    required String parentFolderId,
    required String fileName,
    required int fileSize,
  }) async {
    try {
      final api = await _getDriveApi();
      final escapedName = fileName.replaceAll("'", "\\'");
      final query =
          "name = '$escapedName' and "
          "'$parentFolderId' in parents and "
          "trashed = false";

      final fileList = await api.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name, size)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        for (final f in fileList.files!) {
          final driveSize = int.tryParse(f.size ?? '0') ?? 0;
          if (driveSize == fileSize) {
            return f.id;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Uploads media file to Google Drive with progress tracking and exponential backoff
  Future<drive.File> uploadFile({
    required File file,
    required MediaItem item,
    UploadProgressCallback? onProgress,
  }) async {
    final api = await _getDriveApi();

    // 1. Determine destination folder structure: PhoneBackup/Photos/2026/01
    final year = item.createdAt.year.toString();
    final month = item.createdAt.month.toString().padLeft(2, '0');
    final mediaSubfolder =
        item.mediaType == AppMediaType.video ? AppConstants.videosFolderName : AppConstants.photosFolderName;

    final pathSegments = [
      AppConstants.rootBackupFolderName,
      mediaSubfolder,
      year,
      month,
    ];

    final folderId = await getOrCreateFolderPath(pathSegments);

    // 2. Check if file already exists in this Drive folder
    final existingFileId = await findExistingDriveFile(
      parentFolderId: folderId,
      fileName: item.fileName,
      fileSize: item.fileSize,
    );

    if (existingFileId != null) {
      debugPrint('File ${item.fileName} already exists on Drive: $existingFileId');
      final existingFile = drive.File()..id = existingFileId;
      return existingFile;
    }

    // 3. Prepare upload stream and progress reporting
    final fileLength = await file.length();
    final fileStream = file.openRead();

    final countingStream = ProgressCountingStream(
      fileStream,
      fileLength,
      (sent, total) {
        if (onProgress != null) {
          onProgress(sent, total);
        }
      },
    );

    final media = drive.Media(
      countingStream,
      fileLength,
      contentType: item.mimeType,
    );

    final driveFile = drive.File()
      ..name = item.fileName
      ..parents = [folderId]
      ..description = 'Backed up via Media Backup App. Local ID: ${item.localId}';

    if (item.contentHash != null) {
      driveFile.appProperties = {
        'contentHash': item.contentHash!,
        'localId': item.localId,
      };
    }

    // 4. Execute upload with exponential backoff for transient errors
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final result = await api.files.create(
          driveFile,
          uploadMedia: media,
          $fields: 'id, name, size, md5Checksum, mimeType',
        );

        if (result.id == null || result.id!.isEmpty) {
          throw BackupException('Google Drive returned empty file ID on creation');
        }

        return result;
      } catch (e) {
        debugPrint('Upload attempt $attempt failed: $e');

        if (e is drive.DetailedApiRequestError) {
          if (e.status == 403 &&
              (e.message?.contains('quota') == true ||
                  e.message?.contains('storage') == true)) {
            throw DriveQuotaException(
              'Google Drive storage quota exceeded or permission denied: ${e.message}',
              originalError: e,
            );
          }
          if (e.status == 401) {
            throw AuthException(
              'Google authentication expired or revoked. Please re-authenticate.',
              originalError: e,
            );
          }
        }

        if (attempt >= 3) {
          throw BackupException(
            'Upload failed after $attempt attempts: ${e.toString()}',
            originalError: e,
          );
        }

        // Wait with exponential backoff: 2s, 4s
        final backoffMs = (1 << attempt) * 1000;
        await Future.delayed(Duration(milliseconds: backoffMs));
      }
    }
  }

  /// Clears in-memory folder cache (e.g. on user account change)
  void clearFolderCache() {
    _folderCache.clear();
  }
}
