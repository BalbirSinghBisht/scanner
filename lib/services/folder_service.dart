import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';
import '../providers/backup_provider.dart';
import 'database_helper.dart';
import 'device_settings_helper.dart';
import 'google_drive_service.dart';
import 'media_scanner_service.dart';
import 'vault_service.dart';

/// Manages custom user albums, folder discovery, and moving media across albums.
class FolderService extends ChangeNotifier {
  static final FolderService instance = FolderService._internal();
  FolderService._internal();

  final DatabaseHelper _db = DatabaseHelper.instance;
  final GoogleDriveService _drive = GoogleDriveService.instance;
  final VaultService _vault = VaultService.instance;

  static const String _keyCustomAlbums = 'user_created_custom_albums';
  final Set<String> _customAlbums = {};
  bool _initialized = false;

  Set<String> get customAlbums => Set.unmodifiable(_customAlbums);

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyCustomAlbums) ?? [];
      _customAlbums.addAll(list.map((e) => e.trim()).where((e) => e.isNotEmpty));
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[FolderService] init error: $e');
      _initialized = true;
    }
  }

  /// Creates a new album / folder physically on device and in custom albums registry
  Future<bool> createAlbum(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;

    // Disallow reserved names or junk
    if (trimmed.startsWith('.') ||
        trimmed.toLowerCase() == 'private' ||
        trimmed.toLowerCase() == 'locked' ||
        trimmed.toLowerCase() == 'vault' ||
        MediaScannerService.isJunkOrThumbnail(trimmed, null)) {
      return false;
    }

    await init();

    // Physically create the folder on device so file managers see it immediately
    try {
      final targetPath = await getTargetDirectoryPath(trimmed);
      final dir = Directory(targetPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
    } catch (_) {}

    final added = _customAlbums.add(trimmed);
    if (added) {
      await _saveCustomAlbums();
      notifyListeners();
    }
    return true;
  }

  /// Removes a custom album from the custom albums list
  Future<bool> deleteAlbum(String name) async {
    await init();
    final removed = _customAlbums.remove(name.trim());
    if (removed) {
      await _saveCustomAlbums();
      notifyListeners();
    }
    return removed;
  }

  Future<void> _saveCustomAlbums() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyCustomAlbums, _customAlbums.toList());
    } catch (e) {
      debugPrint('[FolderService] Error saving custom albums: $e');
    }
  }

  /// Returns all available albums/folders (combines physical database folders + custom albums)
  Future<List<String>> getAllAlbums({bool includePrivate = false}) async {
    await init();
    final set = <String>{};

    // 1. Add user-created custom albums
    set.addAll(_customAlbums);

    // 2. Add distinct folders from database
    final dbFolders = await _db.getDistinctFolders();
    for (final f in dbFolders) {
      if (MediaScannerService.isJunkOrThumbnail(f, null)) continue;
      if (!includePrivate &&
          (f.startsWith('.') ||
              f.toLowerCase().contains('private') ||
              f.toLowerCase().contains('locked') ||
              f.toLowerCase().contains('secret') ||
              f.toLowerCase().contains('vault'))) {
        continue;
      }
      set.add(f);
    }

    final list = set.toList();
    list.sort((a, b) {
      // Prioritize Camera, Screenshots, Videos
      if (a == 'Camera') return -1;
      if (b == 'Camera') return 1;
      if (a == 'Screenshots') return -1;
      if (b == 'Screenshots') return 1;
      if (a == 'Videos') return -1;
      if (b == 'Videos') return 1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });

    return list;
  }

  /// Resolves an optimal target directory for storing files in a custom folder.
  /// On Android, uses public shared storage (`/storage/emulated/0/Pictures/[folderName]`)
  /// so that folders and moved files are immediately visible in File Managers.
  Future<String> getTargetDirectoryPath(String folderName) async {
    if (Platform.isAndroid) {
      final picturesDir = Directory('/storage/emulated/0/Pictures/$folderName');
      try {
        if (!picturesDir.existsSync()) {
          picturesDir.createSync(recursive: true);
        }
        return picturesDir.path;
      } catch (_) {}

      final dcimDir = Directory('/storage/emulated/0/DCIM/$folderName');
      try {
        if (!dcimDir.existsSync()) {
          dcimDir.createSync(recursive: true);
        }
        return dcimDir.path;
      } catch (_) {}
    }

    // iOS / Desktop / Sandbox fallback
    Directory baseDir;
    try {
      baseDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      baseDir = Directory.systemTemp;
    }
    final dir = Directory(p.join(baseDir.path, 'Pictures', folderName));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir.path;
  }

  /// Moves a collection of media items from their current location to [targetFolderName].
  /// If [targetFolderName] represents a private/locked folder, delegates to [VaultService].
  /// Automatically syncs with Google Drive by relocating remote files.
  Future<bool> moveItemsToFolder({
    required List<MediaItem> items,
    required String targetFolderName,
    BackupProvider? backupProvider,
  }) async {
    if (items.isEmpty) return true;

    final trimmedTarget = targetFolderName.trim();
    if (trimmedTarget.isEmpty) return false;

    // Check if moving to Private / Locked Folder
    final isTargetPrivate = trimmedTarget.startsWith('.') ||
        trimmedTarget.toLowerCase() == 'private' ||
        trimmedTarget.toLowerCase() == 'locked' ||
        trimmedTarget.toLowerCase() == 'vault' ||
        trimmedTarget.toLowerCase() == 'private (locked)' ||
        trimmedTarget.toLowerCase() == 'secret';

    if (isTargetPrivate) {
      final success = await _vault.moveToVault(items);
      if (backupProvider != null) {
        await backupProvider.refreshData();
      }
      return success;
    }

    // Moving to regular album/folder
    final targetDir = await getTargetDirectoryPath(trimmedTarget);
    final ids = <String>[];
    final pathMap = <String, String>{};

    for (final item in items) {
      ids.add(item.localId);
      String? newPath = item.localFilePath;

      // 1. Resolve source file (from localFilePath or MediaScannerService)
      File? srcFile;
      if (item.localFilePath != null && item.localFilePath!.isNotEmpty) {
        final f = File(item.localFilePath!);
        if (f.existsSync()) srcFile = f;
      }
      srcFile ??= await MediaScannerService.instance.getMediaFile(item.localId);

      // Relocate physical file if possible
      if (srcFile != null && await srcFile.exists()) {
        try {
          final destPath = p.join(targetDir, item.fileName);
          if (destPath != srcFile.path) {
            final bytes = await srcFile.readAsBytes();
            if (bytes.isNotEmpty) {
              final destFile = File(destPath);
              await destFile.writeAsBytes(bytes, flush: true);
              newPath = destPath;

              try {
                await srcFile.delete();
              } catch (_) {}

              MediaScannerService.instance.invalidateCache(item.localId);
              await DeviceSettingsHelper.notifyMediaScanner(destPath, item.mimeType);
              await DeviceSettingsHelper.notifyMediaScanner(srcFile.path, item.mimeType);
            }
          } else {
            newPath = destPath;
          }
        } catch (e) {
          debugPrint('[FolderService] File relocation warning: $e');
        }
      }

      if (newPath != null) {
        pathMap[item.localId] = newPath;
      }

      // Sync data: relocate on Google Drive if already uploaded
      if (item.driveFileId != null && item.driveFileId!.isNotEmpty) {
        unawaited(_drive.moveDriveFile(
          driveFileId: item.driveFileId!,
          targetFolderName: trimmedTarget,
        ));
      }
    }

    // Update manifest database
    await _db.batchUpdateFolder(ids, trimmedTarget, idToNewPath: pathMap);

    // Remove from in-app locked items if previously locked
    await _vault.removeInAppLockedIds(ids);

    // Ensure folder is in custom albums so it remains available
    await createAlbum(trimmedTarget);

    if (backupProvider != null) {
      await backupProvider.refreshData();
    }
    notifyListeners();
    return true;
  }
}

