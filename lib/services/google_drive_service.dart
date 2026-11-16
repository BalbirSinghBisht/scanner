import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
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

  // Root folder in Google Drive (5 TB Shared Drive)
  static const String rootFolderName = 'PhoneBackup';
  static const String canonicalRootFolderId = '1D4WcMHsuG1mLWqjh3dK-9zh_mQV08b6M';
  static const String sharedDriveRootId = '0AJ9AkL5OYh0uUk9PVA';

  // In-memory cache backed by SharedPreferences
  final Map<String, String> _folderCache = {};
  final Map<String, Completer<String>> _inFlightFolderResolutions = {};

  // In-memory cache of remote file names to Drive IDs populated during reconciliation
  Map<String, String>? _cachedRemoteFilesByName;

  void clearRemoteFilesCache() {
    _cachedRemoteFilesByName = null;
  }

  drive.DriveApi? _driveApi;

  void invalidateDriveApi() {
    _driveApi = null;
    _cachedRemoteFilesByName = null;
  }

  Future<drive.DriveApi> _getDriveApi({bool forceRefresh = false}) async {
    if (forceRefresh || _driveApi == null) {
      final client = await _auth.getAuthenticatedClient();
      _driveApi = drive.DriveApi(client);
    }
    return _driveApi!;
  }

  /// Ensures the root PhoneBackup folder exists in the 5 TB Shared Drive, returning its ID.
  Future<String> createRootFolderInMyDrive() async {
    return await getOrCreateFolderPath([rootFolderName]);
  }

  /// Thread-safe and parallel resolution of folder paths with persistent caching in SharedPreferences.
  /// Parallel calls for different folders run concurrently, while calls for the same folder coalesce.
  Future<String> getOrCreateFolderPath(List<String> pathSegments) async {
    final pathKey = pathSegments.join('/');

    // Fast-path 1: in-memory cache hit
    final cached = _folderCache[pathKey];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    // Fast-path 2: coalescing identical in-flight folder requests
    if (_inFlightFolderResolutions.containsKey(pathKey)) {
      return await _inFlightFolderResolutions[pathKey]!.future;
    }

    final completer = Completer<String>();
    _inFlightFolderResolutions[pathKey] = completer;

    try {
      final resolvedId = await _resolveFolderPathLocked(pathSegments);
      _folderCache[pathKey] = resolvedId;
      completer.complete(resolvedId);
      return resolvedId;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _inFlightFolderResolutions.remove(pathKey);
    }
  }

  /// Folders are created on-demand only when data is actively being uploaded into them.
  Future<void> preCreateFolders(List<String> folderNames) async {
    // Intentionally no-op: do not create empty folders upfront.
    // Folders are created strictly JIT when media files are being uploaded.
  }

  /// Deletes any empty child folders under PhoneBackup/<deviceFolder> that do not contain any files.
  /// Ensures only folders containing actual uploaded data exist on Google Drive.
  Future<int> deleteEmptyDriveFolders({Set<String>? keepFolderNames}) async {
    int deleted = 0;
    try {
      final api = await _getDriveApi();
      final deviceFolder =
          await DeviceStateService.instance.getDeviceBackupFolderName();

      // Check root PhoneBackup and deviceFolder exist
      final escapedRoot = rootFolderName.replaceAll("'", "\\'");
      final rootList = await api.files.list(
        q: "name = '$escapedRoot' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
        spaces: 'drive',
        supportsAllDrives: true,
        includeItemsFromAllDrives: true,
        $fields: 'files(id)',
        pageSize: 1,
      );
      if (rootList.files == null || rootList.files!.isEmpty) return 0;
      final rootId = rootList.files!.first.id;
      if (rootId == null) return 0;

      final escapedDev = deviceFolder.replaceAll("'", "\\'");
      final devList = await api.files.list(
        q: "name = '$escapedDev' and mimeType = 'application/vnd.google-apps.folder' and '$rootId' in parents and trashed = false",
        spaces: 'drive',
        supportsAllDrives: true,
        includeItemsFromAllDrives: true,
        $fields: 'files(id)',
        pageSize: 1,
      );
      if (devList.files == null || devList.files!.isEmpty) return 0;
      final deviceFolderId = devList.files!.first.id;
      if (deviceFolderId == null) return 0;

      // List all child folders directly under deviceFolder
      final childFolders = await api.files.list(
        q: "'$deviceFolderId' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
        spaces: 'drive',
        supportsAllDrives: true,
        includeItemsFromAllDrives: true,
        $fields: 'files(id, name)',
        pageSize: 200,
      );

      if (childFolders.files == null || childFolders.files!.isEmpty) return 0;

      for (final folder in childFolders.files!) {
        final fId = folder.id;
        final fName = folder.name;
        if (fId == null || fId.isEmpty || fName == null) continue;

        // Check if this folder has any files
        final items = await api.files.list(
          q: "'$fId' in parents and trashed = false",
          spaces: 'drive',
          supportsAllDrives: true,
          includeItemsFromAllDrives: true,
          $fields: 'files(id)',
          pageSize: 1,
        );

        if (items.files == null || items.files!.isEmpty) {
          // Folder is completely empty (no data uploaded yet): delete it!
          try {
            await api.files.delete(fId, supportsAllDrives: true);
            deleted++;
            debugPrint('[GoogleDriveService] Deleted empty Drive folder with no data: $fName ($fId)');
            final partialPath = '$rootFolderName/$deviceFolder/$fName';
            _folderCache.remove(partialPath);
            final prefKey = 'gdrive_folder_id_${partialPath.replaceAll(RegExp(r'[^\w]'), '_')}';
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(prefKey);
          } catch (e) {
            debugPrint('[GoogleDriveService] Could not delete empty folder $fName: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[GoogleDriveService] Error cleaning empty folders: $e');
    }
    return deleted;
  }

  Future<String> _resolveFolderPathLocked(List<String> pathSegments) async {
    final prefs = await SharedPreferences.getInstance();
    final api = await _getDriveApi();
    String currentParentId = sharedDriveRootId;
    final currentAccumulatedPath = <String>[];

    for (int i = 0; i < pathSegments.length; i++) {
      final segment = pathSegments[i];
      final isRoot = segment == rootFolderName;
      currentAccumulatedPath.add(segment);
      final partialPath = currentAccumulatedPath.join('/');
      final prefKey = 'gdrive_folder_id_${partialPath.replaceAll(RegExp(r'[^\w]'), '_')}';

      String? resolvedFolderId;

      // 1. Check cached folder ID
      final cachedId = _folderCache[partialPath] ?? prefs.getString(prefKey);
      final candidateId = cachedId ?? (isRoot ? canonicalRootFolderId : null);

      if (candidateId != null && candidateId.isNotEmpty) {
        try {
          final existing = await api.files.get(
            candidateId,
            supportsAllDrives: true,
            $fields: 'id, name, parents, trashed',
          );
          if (existing is drive.File && existing.trashed != true) {
            final parents = existing.parents ?? [];
            if (isRoot) {
              resolvedFolderId = candidateId;
            } else if (parents.contains(currentParentId)) {
              resolvedFolderId = candidateId;
            } else {
              // Orphaned folder sitting outside currentParentId.
              // Relocate it directly into currentParentId.
              try {
                final prevParents = parents.join(',');
                await api.files.update(
                  drive.File(),
                  candidateId,
                  addParents: currentParentId,
                  removeParents: prevParents.isNotEmpty ? prevParents : null,
                  supportsAllDrives: true,
                );
                resolvedFolderId = candidateId;
                debugPrint('Relocated orphaned folder $segment into parent $currentParentId');
              } catch (_) {
                resolvedFolderId = null;
              }
            }
          } else {
            // Folder is in trash or was deleted on Drive! Evict stale cached ID
            resolvedFolderId = null;
            _folderCache.remove(partialPath);
            await prefs.remove(prefKey);
            if (isRoot) {
              await clearFolderCache();
            }
          }
        } catch (_) {
          resolvedFolderId = null;
          _folderCache.remove(partialPath);
          await prefs.remove(prefKey);
          if (isRoot) {
            await clearFolderCache();
          }
        }
      }

      // 2. Query Drive under currentParentId if not resolved via cache
      if (resolvedFolderId == null) {
        final escapedSegment = segment.replaceAll("'", "\\'");
        final String query;
        if (isRoot) {
          query =
              "name = '$escapedSegment' and "
              "mimeType = 'application/vnd.google-apps.folder' and "
              "trashed = false";
        } else {
          query =
              "name = '$escapedSegment' and "
              "mimeType = 'application/vnd.google-apps.folder' and "
              "'$currentParentId' in parents and "
              "trashed = false";
        }

        final fileList = await api.files.list(
          q: query,
          spaces: 'drive',
          supportsAllDrives: true,
          includeItemsFromAllDrives: true,
          $fields: 'files(id, name, parents)',
          pageSize: 10,
        );

        if (fileList.files != null && fileList.files!.isNotEmpty) {
          // Always pick first match to prevent folder duplicates
          resolvedFolderId = fileList.files!.first.id;
        } else {
          // Create new folder under currentParentId (or sharedDriveRootId if root)
          final folderMetadata = drive.File()
            ..name = segment
            ..mimeType = 'application/vnd.google-apps.folder';

          if (isRoot) {
            folderMetadata.parents = [sharedDriveRootId];
          } else {
            folderMetadata.parents = [currentParentId];
          }

          final created = await api.files.create(
            folderMetadata,
            supportsAllDrives: true,
            $fields: 'id, name',
          );
          resolvedFolderId = created.id!;
          debugPrint('Created folder "$segment" (id: $resolvedFolderId) under parent: $currentParentId');
        }
      }

      if (resolvedFolderId == null || resolvedFolderId.isEmpty) {
        throw BackupException('Failed to resolve or create Drive folder: $segment');
      }

      _folderCache[partialPath] = resolvedFolderId;
      await prefs.setString(prefKey, resolvedFolderId);
      currentParentId = resolvedFolderId;
    }

    return currentParentId;
  }

  /// Checks if file already exists in target folder or on Drive by name, contentHash, or localId
  Future<String?> findExistingDriveFile({
    required String parentFolderId,
    required String fileName,
    required int fileSize,
    String? contentHash,
    String? localId,
  }) async {
    // 0. Fast-path: in-memory cache lookup from remote summary
    if (_cachedRemoteFilesByName != null) {
      final cachedId = _cachedRemoteFilesByName![fileName];
      if (cachedId != null) {
        return cachedId;
      }
      // Cache miss: proceed to live query to guarantee no duplicates
    }

    try {
      final api = await _getDriveApi();
      final escapedName = fileName.replaceAll("'", "\\'");

      // 1. Search by exact file name inside target folder (if a valid parentFolderId is provided)
      if (parentFolderId.trim().isNotEmpty) {
        final query =
            "name = '$escapedName' and "
            "'$parentFolderId' in parents and "
            "trashed = false";

        final fileList = await api.files.list(
          q: query,
          spaces: 'drive',
          supportsAllDrives: true,
          includeItemsFromAllDrives: true,
          corpora: 'allDrives',
          pageSize: 1,
          $fields: 'files(id, name, size)',
        );

        if (fileList.files != null && fileList.files!.isNotEmpty) {
          final id = fileList.files!.first.id;
          if (id != null) _cachedRemoteFilesByName?[fileName] = id;
          return id;
        }
      }

      // 2. Global search: Check if this file already exists in ANY folder on Drive
      // Prevents duplicating files when they are moved across folders (Camera -> Album -> Vault)
      final globalQuery =
          "name = '$escapedName' and "
          "trashed = false and "
          "mimeType != 'application/vnd.google-apps.folder'";

      final globalList = await api.files.list(
        q: globalQuery,
        spaces: 'drive',
        supportsAllDrives: true,
        includeItemsFromAllDrives: true,
        corpora: 'allDrives',
        pageSize: 5,
        $fields: 'files(id, name, size, parents)',
      );

      if (globalList.files != null && globalList.files!.isNotEmpty) {
        for (final existingFile in globalList.files!) {
          final existingSize = int.tryParse(existingFile.size ?? '') ?? 0;
          if (fileSize <= 0 || existingSize <= 0 || (existingSize - fileSize).abs() < 2048) {
            final id = existingFile.id;
            if (id != null) {
              // Relocate file to the current target folder instead of uploading a duplicate (if parentFolderId provided)
              if (parentFolderId.trim().isNotEmpty) {
                final currentParents = (existingFile.parents ?? []).join(',');
                if (!currentParents.contains(parentFolderId)) {
                  try {
                    await api.files.update(
                      drive.File(),
                      id,
                      addParents: parentFolderId,
                      removeParents: currentParents.isNotEmpty ? currentParents : null,
                      supportsAllDrives: true,
                    );
                    debugPrint('[GoogleDriveService] Relocated existing Drive file $fileName ($id) to $parentFolderId (prevented duplicate upload)');
                  } catch (e) {
                    debugPrint('[GoogleDriveService] Relocation warning: $e');
                  }
                }
              }
              _cachedRemoteFilesByName?[fileName] = id;
              return id;
            }
          }
        }
      }

      // 3. Search by localId in appProperties
      if (localId != null && localId.isNotEmpty) {
        try {
          final localIdQuery =
              "appProperties has { key='localId' and value='$localId' } and "
              "trashed = false";
          final localIdList = await api.files.list(
            q: localIdQuery,
            spaces: 'drive',
            supportsAllDrives: true,
            includeItemsFromAllDrives: true,
            corpora: 'allDrives',
            pageSize: 1,
            $fields: 'files(id, name)',
          );
          if (localIdList.files != null && localIdList.files!.isNotEmpty) {
            final id = localIdList.files!.first.id;
            if (id != null) _cachedRemoteFilesByName?[fileName] = id;
            return id;
          }
        } catch (_) {}
      }

      // 4. Search by contentHash in appProperties if available
      if (contentHash != null && contentHash.isNotEmpty) {
        try {
          final hashQuery =
              "appProperties has { key='contentHash' and value='$contentHash' } and "
              "trashed = false";
          final hashList = await api.files.list(
            q: hashQuery,
            spaces: 'drive',
            supportsAllDrives: true,
            includeItemsFromAllDrives: true,
            corpora: 'allDrives',
            pageSize: 1,
            $fields: 'files(id, name)',
          );
          if (hashList.files != null && hashList.files!.isNotEmpty) {
            final id = hashList.files!.first.id;
            if (id != null) _cachedRemoteFilesByName?[fileName] = id;
            return id;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[GoogleDriveService] Error finding existing Drive file: $e');
      if (e is drive.DetailedApiRequestError && e.status == 401) {
        invalidateDriveApi();
        await _auth.refreshActiveSession();
      }
    }
    return null;
  }

  /// Scans Google Drive and purges any duplicate files in the backup folders
  /// Keeps the newest copy and deletes redundant duplicates
  Future<int> cleanDuplicateDriveFiles() async {
    int deletedCount = 0;
    try {
      final api = await _getDriveApi();
      final seenFiles = <String, drive.File>{};
      String? pageToken;

      do {
        final list = await api.files.list(
          q: "trashed = false and mimeType != 'application/vnd.google-apps.folder'",
          spaces: 'drive',
          supportsAllDrives: true,
          includeItemsFromAllDrives: true,
          corpora: 'allDrives',
          $fields: 'nextPageToken, files(id, name, size, parents, modifiedTime)',
          pageToken: pageToken,
          pageSize: 500,
        );

        if (list.files != null) {
          for (final f in list.files!) {
            if (f.id == null || f.name == null) continue;
            final parent = (f.parents ?? []).join(',');
            final key = '${f.name}::$parent';

            if (seenFiles.containsKey(key)) {
              // Found duplicate in the exact same folder!
              final duplicateToDelete = f.id!;
              try {
                await api.files.delete(duplicateToDelete, supportsAllDrives: true);
                deletedCount++;
                debugPrint('[GoogleDriveService] Purged duplicate file on Drive: ${f.name} ($duplicateToDelete)');
              } catch (_) {}
            } else {
              seenFiles[key] = f;
            }
          }
        }
        pageToken = list.nextPageToken;
      } while (pageToken != null && pageToken.isNotEmpty);

      _cachedRemoteFilesByName = null;
    } catch (e) {
      debugPrint('[GoogleDriveService] Error cleaning duplicate Drive files: $e');
    }
    return deletedCount;
  }

  /// Ensures no two folders share the same name under the device backup folder on Google Drive.
  /// Consolidates duplicate folders by moving contents into the canonical folder and removing duplicates.
  Future<int> cleanDuplicateDriveFolders() async {
    int mergedOrDeleted = 0;
    try {
      final api = await _getDriveApi();
      final escapedRoot = rootFolderName.replaceAll("'", "\\'");
      final rootList = await api.files.list(
        q: "name = '$escapedRoot' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
        spaces: 'drive',
        supportsAllDrives: true,
        includeItemsFromAllDrives: true,
        $fields: 'files(id)',
        pageSize: 1,
      );
      if (rootList.files == null || rootList.files!.isEmpty) return 0;
      final rootId = rootList.files!.first.id;
      if (rootId == null) return 0;

      final deviceFolder =
          await DeviceStateService.instance.getDeviceBackupFolderName();
      final escapedDev = deviceFolder.replaceAll("'", "\\'");

      final devList = await api.files.list(
        q: "name = '$escapedDev' and mimeType = 'application/vnd.google-apps.folder' and '$rootId' in parents and trashed = false",
        spaces: 'drive',
        supportsAllDrives: true,
        includeItemsFromAllDrives: true,
        $fields: 'files(id)',
        pageSize: 10,
      );

      if (devList.files == null || devList.files!.isEmpty) return 0;
      final deviceFolderId = devList.files!.first.id;
      if (deviceFolderId == null) return 0;

      // If duplicate device folders exist, remove extra empty ones
      if (devList.files!.length > 1) {
        for (int i = 1; i < devList.files!.length; i++) {
          final dupDevId = devList.files![i].id;
          if (dupDevId != null) {
            try {
              await api.files.delete(dupDevId, supportsAllDrives: true);
              mergedOrDeleted++;
            } catch (_) {}
          }
        }
      }

      // List all child folders directly under deviceFolder
      final childFolders = await api.files.list(
        q: "'$deviceFolderId' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
        spaces: 'drive',
        supportsAllDrives: true,
        includeItemsFromAllDrives: true,
        $fields: 'files(id, name)',
        pageSize: 500,
      );

      if (childFolders.files == null || childFolders.files!.isEmpty) return mergedOrDeleted;

      final foldersByName = <String, List<drive.File>>{};
      for (final f in childFolders.files!) {
        if (f.name == null || f.id == null) continue;
        foldersByName.putIfAbsent(f.name!, () => []).add(f);
      }

      for (final entry in foldersByName.entries) {
        final list = entry.value;
        if (list.length > 1) {
          debugPrint('[GoogleDriveService] Found ${list.length} duplicate folders named "${entry.key}" on Drive. Consolidating...');
          final primaryFolderId = list.first.id!;

          for (int i = 1; i < list.length; i++) {
            final dupFolderId = list[i].id;
            if (dupFolderId == null) continue;

            // Move any files in duplicate folder to primary folder
            try {
              final dupFiles = await api.files.list(
                q: "'$dupFolderId' in parents and trashed = false",
                spaces: 'drive',
                supportsAllDrives: true,
                includeItemsFromAllDrives: true,
                $fields: 'files(id)',
                pageSize: 100,
              );

              if (dupFiles.files != null) {
                for (final file in dupFiles.files!) {
                  if (file.id != null) {
                    await api.files.update(
                      drive.File(),
                      file.id!,
                      addParents: primaryFolderId,
                      removeParents: dupFolderId,
                      supportsAllDrives: true,
                    );
                  }
                }
              }

              // Delete the duplicate folder now that it's empty
              await api.files.delete(dupFolderId, supportsAllDrives: true);
              mergedOrDeleted++;
              debugPrint('[GoogleDriveService] Consolidated and deleted duplicate Drive folder "${entry.key}" ($dupFolderId)');
            } catch (e) {
              debugPrint('[GoogleDriveService] Error consolidating duplicate folder "${entry.key}": $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[GoogleDriveService] Error cleaning duplicate Drive folders: $e');
    }
    return mergedOrDeleted;
  }

  /// Checks whether the device backup folder (PhoneBackup/<deviceFolder>) exists and is NOT trashed on Google Drive.
  Future<bool> doesDeviceFolderExist() async {
    try {
      final api = await _getDriveApi();
      final deviceFolder =
          await DeviceStateService.instance.getDeviceBackupFolderName();

      // 1. Verify root PhoneBackup exists and is not trashed
      final escapedRoot = rootFolderName.replaceAll("'", "\\'");
      final rootList = await api.files.list(
        q: "name = '$escapedRoot' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
        spaces: 'drive',
        supportsAllDrives: true,
        includeItemsFromAllDrives: true,
        $fields: 'files(id, name, trashed)',
        pageSize: 5,
      );

      if (rootList.files == null || rootList.files!.isEmpty) {
        return false;
      }

      final rootIds = rootList.files!.map((f) => f.id).whereType<String>().toList();
      if (rootIds.isEmpty) return false;

      // 2. Verify deviceFolder exists inside the root and is not trashed
      final escapedDevice = deviceFolder.replaceAll("'", "\\'");
      final devQuery = rootIds.length == 1
          ? "name = '$escapedDevice' and mimeType = 'application/vnd.google-apps.folder' and '${rootIds.first}' in parents and trashed = false"
          : "name = '$escapedDevice' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";

      final devList = await api.files.list(
        q: devQuery,
        spaces: 'drive',
        supportsAllDrives: true,
        includeItemsFromAllDrives: true,
        $fields: 'files(id, name, parents, trashed)',
        pageSize: 10,
      );

      if (devList.files == null || devList.files!.isEmpty) {
        return false;
      }

      if (rootIds.length > 1) {
        final hasValidParent = devList.files!.any((f) {
          final parents = f.parents ?? [];
          return parents.any((p) => rootIds.contains(p));
        });
        if (!hasValidParent) return false;
      }

      return true;
    } catch (e) {
      debugPrint('[GoogleDriveService] Error checking doesDeviceFolderExist: $e');
      if (e is drive.DetailedApiRequestError && e.status == 401) {
        invalidateDriveApi();
        await _auth.refreshActiveSession();
      }
      return true; // on network or transient error, don't falsely conclude it was deleted
    }
  }

  /// Fetches a mapping of all accessible media files on Google Drive
  /// Returns a record with Map of {fileName: fileId}, Set of {fileId}, and success flag
  Future<({Map<String, String> filesByName, Set<String> fileIds, bool success})> fetchRemoteFilesSummary() async {
    final filesByName = <String, String>{};
    final fileIds = <String>{};
    bool success = false;

    try {
      final exists = await doesDeviceFolderExist();
      if (!exists) {
        debugPrint('[GoogleDriveService] Device backup folder does not exist or is trashed on Drive.');
        _cachedRemoteFilesByName = filesByName;
        return (filesByName: filesByName, fileIds: fileIds, success: true);
      }

      final api = await _getDriveApi();
      String? pageToken;
      do {
        final list = await api.files.list(
          q: "trashed = false and mimeType != 'application/vnd.google-apps.folder'",
          spaces: 'drive',
          supportsAllDrives: true,
          includeItemsFromAllDrives: true,
          corpora: 'allDrives',
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
      _cachedRemoteFilesByName = filesByName;
      success = true;
    } catch (e) {
      debugPrint('Error fetching remote drive files summary: $e');
      if (e is drive.DetailedApiRequestError && e.status == 401) {
        invalidateDriveApi();
        await _auth.refreshActiveSession();
      }
    }

    return (filesByName: filesByName, fileIds: fileIds, success: success);
  }

  /// Uploads media file to Google Drive under PhoneBackup/`Device`/Photos or Videos
  Future<drive.File> uploadFile({
    required File file,
    required MediaItem item,
    UploadProgressCallback? onProgress,
  }) async {
    // 1. Destination folder structure: PhoneBackup as root, then device folder, then matching phone folder (e.g. Camera, Screenshots, WhatsApp Images)
    final deviceFolder =
        await DeviceStateService.instance.getDeviceBackupFolderName();
    final phoneFolder = item.displayFolderName;
    final pathSegments = [rootFolderName, deviceFolder, phoneFolder];

    String folderId = await getOrCreateFolderPath(pathSegments);

    // 2. Check if file already exists in this Drive folder to prevent duplicate uploads
    final existingFileId = await findExistingDriveFile(
      parentFolderId: folderId,
      fileName: item.fileName,
      fileSize: item.fileSize,
      contentHash: item.contentHash,
      localId: item.localId,
    );

    if (existingFileId != null) {
      debugPrint('File ${item.fileName} already exists on Drive: $existingFileId');
      final existingFile = drive.File()..id = existingFileId;
      return existingFile;
    }

    final fileLength = await file.length();

    // 3. Execute upload with exponential backoff for transient errors
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final api = await _getDriveApi();
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

        driveFile.appProperties = {
          'localId': item.localId,
          if (item.contentHash != null && item.contentHash!.isNotEmpty)
            'contentHash': item.contentHash!,
        };

        final uploadOptions = fileLength > 5 * 1024 * 1024
            ? drive.UploadOptions.resumable
            : drive.UploadOptions.defaultOptions;

        final result = await api.files.create(
          driveFile,
          uploadMedia: media,
          uploadOptions: uploadOptions,
          supportsAllDrives: true,
          $fields: 'id, name, size, md5Checksum, mimeType',
        );

        if (result.id == null || result.id!.isEmpty) {
          throw BackupException('Google Drive returned empty file ID on creation');
        }

        if (result.id != null) {
          _cachedRemoteFilesByName?[item.fileName] = result.id!;
        }

        return result;
      } catch (e) {
        debugPrint('Upload attempt $attempt failed: $e');

        if (e is drive.DetailedApiRequestError) {
          if (e.status == 404) {
            debugPrint('[GoogleDriveService] 404 Not Found during upload. Clearing folder cache and resolving folder again...');
            await clearFolderCache();
            try {
              folderId = await getOrCreateFolderPath(pathSegments);
            } catch (_) {}
          }
          if (e.status == 403 &&
              (e.message?.contains('quota') == true ||
                  e.message?.contains('storage') == true)) {
            throw DriveQuotaException(
              'Google Drive storage quota exceeded or permission denied: ${e.message}',
              originalError: e,
            );
          }
          if (e.status == 401) {
            invalidateDriveApi();
            final refreshed = await _auth.refreshActiveSession();
            if (refreshed && attempt < 3) {
              debugPrint('Refreshed session on 401, retrying upload...');
              // Before creating file again, double check if file exists on Drive to prevent duplicate
              final doubleCheckId = await findExistingDriveFile(
                parentFolderId: folderId,
                fileName: item.fileName,
                fileSize: item.fileSize,
                contentHash: item.contentHash,
                localId: item.localId,
              );
              if (doubleCheckId != null) {
                debugPrint('File ${item.fileName} was already uploaded on Drive ($doubleCheckId)! Avoiding duplicate.');
                return drive.File()..id = doubleCheckId;
              }
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

  /// Relocates a file on Google Drive to a new target folder under PhoneBackup/`deviceFolder`/`targetFolderName`
  Future<bool> moveDriveFile({
    required String driveFileId,
    required String targetFolderName,
  }) async {
    try {
      final api = await _getDriveApi();
      final deviceFolder =
          await DeviceStateService.instance.getDeviceBackupFolderName();
      final pathSegments = [rootFolderName, deviceFolder, targetFolderName];
      final targetFolderId = await getOrCreateFolderPath(pathSegments);

      final fileInfo = await api.files.get(
        driveFileId,
        supportsAllDrives: true,
        $fields: 'id, parents',
      );

      if (fileInfo is drive.File) {
        final currentParents = (fileInfo.parents ?? []).join(',');
        await api.files.update(
          drive.File(),
          driveFileId,
          addParents: targetFolderId,
          removeParents: currentParents.isNotEmpty ? currentParents : null,
          supportsAllDrives: true,
        );
        debugPrint('[GoogleDriveService] Relocated Drive file $driveFileId to $targetFolderName ($targetFolderId)');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[GoogleDriveService] Error moving file on Drive: $e');
      return false;
    }
  }

  /// Downloads file content bytes directly from Google Drive (e.g. for cloud-only items)
  Future<Uint8List?> downloadFileBytes(String driveFileId) async {
    try {
      final api = await _getDriveApi();
      final media = await api.files.get(
        driveFileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
        supportsAllDrives: true,
      );

      if (media is drive.Media) {
        final bytesBuilder = BytesBuilder(copy: false);
        await for (final chunk in media.stream) {
          bytesBuilder.add(chunk);
        }
        final bytes = bytesBuilder.toBytes();
        return bytes.isNotEmpty ? bytes : null;
      }
      return null;
    } catch (e) {
      debugPrint('[GoogleDriveService] Download file bytes warning: $e');
      return null;
    }
  }

  /// Clears in-memory and persisted folder cache (e.g. on user account change)
  Future<void> clearFolderCache() async {
    _folderCache.clear();
    _inFlightFolderResolutions.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys().where((k) => k.startsWith('gdrive_folder_id_')).toList();
      for (final k in allKeys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}
