import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/errors/app_exceptions.dart';
import '../models/media_item.dart';
import 'auth_service.dart';
import 'device_state_service.dart';

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

  // Root folder in Google Drive
  static const String rootFolderName = 'PhoneBackup';

  // In-memory cache backed by SharedPreferences
  final Map<String, String> _folderCache = {};
  Completer<void>? _folderLock;

  drive.DriveApi? _driveApi;

  Future<drive.DriveApi> _getDriveApi() async {
    final client = await _auth.getAuthenticatedClient();
    _driveApi = drive.DriveApi(client);
    return _driveApi!;
  }

  /// Thread-safe resolution of folder paths with persistent caching in SharedPreferences
  Future<String> getOrCreateFolderPath(List<String> pathSegments) async {
    while (_folderLock != null) {
      await _folderLock!.future;
    }
    _folderLock = Completer<void>();
    try {
      return await _resolveFolderPathLocked(pathSegments);
    } finally {
      final lock = _folderLock;
      _folderLock = null;
      lock?.complete();
    }
  }

  Future<String> _resolveFolderPathLocked(List<String> pathSegments) async {
    final prefs = await SharedPreferences.getInstance();
    final api = await _getDriveApi();
    String currentParentId = 'root';
    final currentAccumulatedPath = <String>[];

    for (final segment in pathSegments) {
      currentAccumulatedPath.add(segment);
      final partialPath = currentAccumulatedPath.join('/');
      final prefKey = 'gdrive_folder_id_${partialPath.replaceAll(RegExp(r'[^\w]'), '_')}';

      // 1. Check in-memory cache
      if (_folderCache.containsKey(partialPath)) {
        currentParentId = _folderCache[partialPath]!;
        continue;
      }

      // 2. Check persistent SharedPreferences cache
      final savedId = prefs.getString(prefKey) ??
          (segment == rootFolderName ? '1y27LUA1lGyAu7zbyLfNSJ4VDu5V_f8hX' : null);
      if (savedId != null && savedId.isNotEmpty) {
        try {
          final existing = await api.files.get(
            savedId,
            supportsAllDrives: true,
            $fields: 'id, trashed',
          );
          if (existing is drive.File && existing.trashed != true) {
            _folderCache[partialPath] = savedId;
            currentParentId = savedId;
            continue;
          }
        } catch (_) {
          // Folder no longer exists or inaccessible, fall through to re-query / re-create
        }
      }

      // 3. Query Drive under currentParentId to see if folder exists
      final escapedSegment = segment.replaceAll("'", "\\'");
      final query =
          "name = '$escapedSegment' and "
          "mimeType = 'application/vnd.google-apps.folder' and "
          "'$currentParentId' in parents and "
          "trashed = false";

      final fileList = await api.files.list(
        q: query,
        spaces: 'drive',
        supportsAllDrives: true,
        includeItemsFromAllDrives: true,
        $fields: 'files(id, name)',
      );

      String folderId;
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        folderId = fileList.files!.first.id!;
      } else {
        // Create new folder under currentParentId
        final folderMetadata = drive.File()
          ..name = segment
          ..mimeType = 'application/vnd.google-apps.folder'
          ..parents = [currentParentId];

        final created = await api.files.create(
          folderMetadata,
          supportsAllDrives: true,
          $fields: 'id, name',
        );
        folderId = created.id!;
      }

      _folderCache[partialPath] = folderId;
      await prefs.setString(prefKey, folderId);
      currentParentId = folderId;
    }

    return currentParentId;
  }

  /// Checks if file already exists in target folder by name or contentHash to avoid duplicate uploads
  Future<String?> findExistingDriveFile({
    required String parentFolderId,
    required String fileName,
    required int fileSize,
    String? contentHash,
  }) async {
    try {
      final api = await _getDriveApi();
      final escapedName = fileName.replaceAll("'", "\\'");

      // 1. Search by exact file name inside target folder
      final query =
          "name = '$escapedName' and "
          "'$parentFolderId' in parents and "
          "trashed = false";

      final fileList = await api.files.list(
        q: query,
        spaces: 'drive',
        supportsAllDrives: true,
        includeItemsFromAllDrives: true,
        $fields: 'files(id, name, size)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id;
      }

      // 2. Search by contentHash in target folder if available
      if (contentHash != null && contentHash.isNotEmpty) {
        final hashQuery =
            "appProperties has { key='contentHash' and value='$contentHash' } and "
            "'$parentFolderId' in parents and "
            "trashed = false";
        final hashList = await api.files.list(
          q: hashQuery,
          spaces: 'drive',
          supportsAllDrives: true,
          includeItemsFromAllDrives: true,
          $fields: 'files(id, name)',
        );
        if (hashList.files != null && hashList.files!.isNotEmpty) {
          return hashList.files!.first.id;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Fetches a mapping of all accessible media files on Google Drive
  /// Returns a record with Map of {fileName: fileId} and Set of {fileId}
  Future<({Map<String, String> filesByName, Set<String> fileIds})> fetchRemoteFilesSummary() async {
    final filesByName = <String, String>{};
    final fileIds = <String>{};

    try {
      final api = await _getDriveApi();
      String? pageToken;
      do {
        final list = await api.files.list(
          q: "trashed = false and mimeType != 'application/vnd.google-apps.folder'",
          spaces: 'drive',
          supportsAllDrives: true,
          includeItemsFromAllDrives: true,
          $fields: 'nextPageToken, files(id, name, appProperties)',
          pageToken: pageToken,
          pageSize: 500,
        );

        if (list.files != null) {
          for (final f in list.files!) {
            if (f.id != null && f.id!.isNotEmpty) {
              fileIds.add(f.id!);
              if (f.name != null && f.name!.isNotEmpty) {
                filesByName[f.name!] = f.id!;
              }
            }
          }
        }
        pageToken = list.nextPageToken;
      } while (pageToken != null && pageToken.isNotEmpty);
    } catch (e) {
      debugPrint('Error fetching remote drive files summary: $e');
    }

    return (filesByName: filesByName, fileIds: fileIds);
  }

  /// Uploads media file to Google Drive under PhoneBackup/`Device`/Photos or Videos
  Future<drive.File> uploadFile({
    required File file,
    required MediaItem item,
    UploadProgressCallback? onProgress,
  }) async {
    final api = await _getDriveApi();

    // 1. Destination folder structure: PhoneBackup as root, then device folder, then matching phone folder (e.g. Camera, Screenshots, WhatsApp Images)
    final deviceFolder =
        await DeviceStateService.instance.getDeviceBackupFolderName();
    final phoneFolder = item.displayFolderName;
    final pathSegments = [rootFolderName, deviceFolder, phoneFolder];

    final folderId = await getOrCreateFolderPath(pathSegments);

    // 2. Check if file already exists in this Drive folder to prevent duplicate uploads
    final existingFileId = await findExistingDriveFile(
      parentFolderId: folderId,
      fileName: item.fileName,
      fileSize: item.fileSize,
      contentHash: item.contentHash,
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
          supportsAllDrives: true,
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
            final refreshed = await _auth.refreshDirectAccessToken();
            if (refreshed != null && attempt < 3) {
              debugPrint('Refreshed token on 401, retrying upload...');
              continue;
            }
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
