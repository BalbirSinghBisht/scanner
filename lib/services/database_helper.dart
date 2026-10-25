import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../core/constants/app_constants.dart';
import '../models/media_item.dart';
import '../models/dashboard_stats.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(AppConstants.databaseName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${AppConstants.manifestTableName} (
        local_id TEXT PRIMARY KEY,
        file_name TEXT NOT NULL,
        media_type TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        width INTEGER,
        height INTEGER,
        duration_seconds INTEGER,
        created_at INTEGER NOT NULL,
        modified_at INTEGER,
        content_hash TEXT,
        drive_file_id TEXT,
        upload_state TEXT NOT NULL,
        last_attempt_at INTEGER,
        uploaded_at INTEGER,
        error_message TEXT,
        retry_count INTEGER NOT NULL DEFAULT 0,
        bytes_uploaded INTEGER NOT NULL DEFAULT 0,
        drive_folder_path TEXT,
        local_file_path TEXT,
        folder_name TEXT
      )
    ''');

    // Indices for performance
    await db.execute(
      'CREATE INDEX idx_upload_state ON ${AppConstants.manifestTableName} (upload_state)',
    );
    await db.execute(
      'CREATE INDEX idx_media_type ON ${AppConstants.manifestTableName} (media_type)',
    );
    await db.execute(
      'CREATE INDEX idx_content_hash ON ${AppConstants.manifestTableName} (content_hash)',
    );
    await db.execute(
      'CREATE INDEX idx_created_at ON ${AppConstants.manifestTableName} (created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_folder_name ON ${AppConstants.manifestTableName} (folder_name)',
    );
  }

  Future<void> _onUpgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
          'ALTER TABLE ${AppConstants.manifestTableName} ADD COLUMN folder_name TEXT',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_folder_name ON ${AppConstants.manifestTableName} (folder_name)',
        );
      } catch (_) {}
    }
  }

  /// Recovers any interrupted transfers from previous app lifecycle.
  /// Only reverts items that have been stuck in 'UPLOADING' state for more than [timeoutMinutes]
  /// to ensure active transfers running in another isolate/thread are not disrupted.
  Future<int> recoverInterruptedUploads({int timeoutMinutes = 5}) async {
    final db = await database;
    final cutoffMs = DateTime.now()
        .subtract(Duration(minutes: timeoutMinutes))
        .millisecondsSinceEpoch;
    return await db.rawUpdate('''
      UPDATE ${AppConstants.manifestTableName}
      SET upload_state = ?,
          error_message = ?
      WHERE upload_state = ? AND (last_attempt_at IS NULL OR last_attempt_at < ?)
    ''', [
      UploadState.RETRY_PENDING.name,
      'Interrupted transfer timed out. Queued for resume.',
      UploadState.UPLOADING.name,
      cutoffMs,
    ]);
  }

  /// Reconciles local SQLite state with actual remote files on Google Drive.
  /// 1. Any file currently on Google Drive is ensured to be marked UPLOADED (prevents duplicate uploads).
  /// 2. Any file marked UPLOADED locally that NO LONGER exists on Google Drive (e.g. user deleted it from Drive)
  ///    is reset to READY_TO_UPLOAD (automatically re-syncs to Drive without needing to clear app data).
  Future<void> reconcileWithDrive(
    Map<String, String> remoteFilesByName,
    Set<String> remoteFileIds,
  ) async {
    final db = await database;

    // A. For any item currently marked UPLOADED in SQLite:
    // If its driveFileId is NOT in remoteFileIds AND its fileName is NOT in remoteFilesByName,
    // the user deleted it from Drive! Reset it to READY_TO_UPLOAD.
    final uploadedItems = await db.query(
      AppConstants.manifestTableName,
      where: 'upload_state = ?',
      whereArgs: [UploadState.UPLOADED.name],
    );

    final toResetIds = <String>[];
    for (final map in uploadedItems) {
      final driveId = map['drive_file_id'] as String?;
      final localId = map['local_id'] as String;
      final fileName = map['file_name'] as String;

      if ((driveId == null || !remoteFileIds.contains(driveId)) &&
          !remoteFilesByName.containsKey(fileName)) {
        toResetIds.add(localId);
      }
    }

    if (toResetIds.isNotEmpty) {
      final batch = db.batch();
      for (final id in toResetIds) {
        batch.update(
          AppConstants.manifestTableName,
          {
            'upload_state': UploadState.READY_TO_UPLOAD.name,
            'drive_file_id': null,
            'uploaded_at': null,
          },
          where: 'local_id = ?',
          whereArgs: [id],
        );
      }
      await batch.commit(noResult: true);
      debugPrint('Reset ${toResetIds.length} items to READY_TO_UPLOAD because they were removed from Google Drive.');
    }

    // B. For any item in SQLite NOT marked UPLOADED:
    // If it ALREADY exists on Google Drive, mark it UPLOADED with the remote ID!
    final pendingItems = await db.query(
      AppConstants.manifestTableName,
      where: 'upload_state != ?',
      whereArgs: [UploadState.UPLOADED.name],
    );

    final toMarkUploaded = <String, String>{};
    for (final map in pendingItems) {
      final fileName = map['file_name'] as String;
      final localId = map['local_id'] as String;
      if (remoteFilesByName.containsKey(fileName)) {
        toMarkUploaded[localId] = remoteFilesByName[fileName]!;
      }
    }

    if (toMarkUploaded.isNotEmpty) {
      final batch = db.batch();
      toMarkUploaded.forEach((localId, driveId) {
        batch.update(
          AppConstants.manifestTableName,
          {
            'upload_state': UploadState.UPLOADED.name,
            'drive_file_id': driveId,
            'uploaded_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'local_id = ?',
          whereArgs: [localId],
        );
      });
      await batch.commit(noResult: true);
      debugPrint('Marked ${toMarkUploaded.length} items as UPLOADED because they already exist on Google Drive.');
    }
  }

  Future<int> upsertMediaItem(MediaItem item) async {
    final db = await database;
    return await db.insert(
      AppConstants.manifestTableName,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> batchUpsertMediaItems(List<MediaItem> items) async {
    if (items.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        AppConstants.manifestTableName,
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<MediaItem?> getItemByLocalId(String localId) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.manifestTableName,
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return MediaItem.fromMap(maps.first);
    }
    return null;
  }

  Future<MediaItem?> getItemByPath(String path) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.manifestTableName,
      where: 'local_file_path = ?',
      whereArgs: [path],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return MediaItem.fromMap(maps.first);
    }
    return null;
  }

  Future<MediaItem?> getItemByContentHash(String contentHash) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.manifestTableName,
      where: 'content_hash = ? AND upload_state = ?',
      whereArgs: [contentHash, UploadState.UPLOADED.name],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return MediaItem.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updateUploadState(
    String localId,
    UploadState state, {
    String? driveFileId,
    String? errorMessage,
    int? bytesUploaded,
    int? retryCount,
    DateTime? lastAttemptAt,
    DateTime? uploadedAt,
  }) async {
    final db = await database;
    final values = <String, dynamic>{
      'upload_state': state.name,
    };
    if (driveFileId != null) values['drive_file_id'] = driveFileId;
    if (errorMessage != null) values['error_message'] = errorMessage;
    if (bytesUploaded != null) values['bytes_uploaded'] = bytesUploaded;
    if (retryCount != null) values['retry_count'] = retryCount;
    if (lastAttemptAt != null) {
      values['last_attempt_at'] = lastAttemptAt.millisecondsSinceEpoch;
    }
    if (uploadedAt != null) {
      values['uploaded_at'] = uploadedAt.millisecondsSinceEpoch;
    }

    await db.update(
      AppConstants.manifestTableName,
      values,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> updateContentHash(String localId, String hash) async {
    final db = await database;
    await db.update(
      AppConstants.manifestTableName,
      {'content_hash': hash},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> updateLocalFilePath(String localId, String path) async {
    final db = await database;
    await db.update(
      AppConstants.manifestTableName,
      {'local_file_path': path},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Get next eligible items to upload according to photo/video settings and retry counts
  Future<List<MediaItem>> getPendingUploads({
    bool includePhotos = true,
    bool includeVideos = true,
    int? maxVideoSizeBytes,
    int limit = 50,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[
      UploadState.READY_TO_UPLOAD.name,
      UploadState.RETRY_PENDING.name,
    ];

    conditions.add('(upload_state = ? OR upload_state = ?)');

    if (!includePhotos && !includeVideos) {
      return [];
    } else if (includePhotos && !includeVideos) {
      conditions.add('media_type = ?');
      args.add(AppMediaType.image.name);
    } else if (!includePhotos && includeVideos) {
      conditions.add('media_type = ?');
      args.add(AppMediaType.video.name);
    }

    if (maxVideoSizeBytes != null && maxVideoSizeBytes > 0) {
      conditions.add(
        '(media_type = ? OR (media_type = ? AND file_size <= ?))',
      );
      args.add(AppMediaType.image.name);
      args.add(AppMediaType.video.name);
      args.add(maxVideoSizeBytes);
    }

    final whereClause = conditions.join(' AND ');

    final maps = await db.query(
      AppConstants.manifestTableName,
      where: whereClause,
      whereArgs: args,
      orderBy: 'created_at ASC',
      limit: limit,
    );

    return maps.map((m) => MediaItem.fromMap(m)).toList();
  }

  /// Atomically claims a single pending item by transitioning its state to UPLOADING in a transaction.
  /// Prevents race conditions between multiple isolates (e.g. background service and foreground app).
  Future<MediaItem?> claimNextPendingUpload({
    bool includePhotos = true,
    bool includeVideos = true,
    int? maxVideoSizeBytes,
  }) async {
    final db = await database;
    return await db.transaction<MediaItem?>((txn) async {
      final conditions = <String>[];
      final args = <dynamic>[
        UploadState.READY_TO_UPLOAD.name,
        UploadState.RETRY_PENDING.name,
      ];

      conditions.add('(upload_state = ? OR upload_state = ?)');

      if (!includePhotos && !includeVideos) {
        return null;
      } else if (includePhotos && !includeVideos) {
        conditions.add('media_type = ?');
        args.add(AppMediaType.image.name);
      } else if (!includePhotos && includeVideos) {
        conditions.add('media_type = ?');
        args.add(AppMediaType.video.name);
      }

      if (maxVideoSizeBytes != null && maxVideoSizeBytes > 0) {
        conditions.add(
          '(media_type = ? OR (media_type = ? AND file_size <= ?))',
        );
        args.add(AppMediaType.image.name);
        args.add(AppMediaType.video.name);
        args.add(maxVideoSizeBytes);
      }

      final whereClause = conditions.join(' AND ');

      final maps = await txn.query(
        AppConstants.manifestTableName,
        where: whereClause,
        whereArgs: args,
        orderBy: 'created_at ASC',
        limit: 1,
      );

      if (maps.isEmpty) {
        return null;
      }

      final item = MediaItem.fromMap(maps.first);
      final now = DateTime.now().toIso8601String();

      await txn.update(
        AppConstants.manifestTableName,
        {
          'upload_state': UploadState.UPLOADING.name,
          'last_attempt_at': now,
        },
        where: 'local_id = ?',
        whereArgs: [item.localId],
      );

      return item.copyWith(
        uploadState: UploadState.UPLOADING,
        lastAttemptAt: DateTime.parse(now),
      );
    });
  }

  Future<List<MediaItem>> getFailedUploads({int limit = 100}) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.manifestTableName,
      where: 'upload_state = ?',
      whereArgs: [UploadState.FAILED.name],
      orderBy: 'last_attempt_at DESC',
      limit: limit,
    );
    return maps.map((m) => MediaItem.fromMap(m)).toList();
  }

  Future<List<MediaItem>> getRecentUploads({int limit = 20}) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.manifestTableName,
      where: 'upload_state = ?',
      whereArgs: [UploadState.UPLOADED.name],
      orderBy: 'uploaded_at DESC',
      limit: limit,
    );
    return maps.map((m) => MediaItem.fromMap(m)).toList();
  }

  Future<List<MediaItem>> getAllItems({
    String? mediaTypeFilter,
    String? stateFilter,
    int limit = 200,
    int offset = 0,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (mediaTypeFilter != null && mediaTypeFilter.isNotEmpty) {
      conditions.add('media_type = ?');
      args.add(mediaTypeFilter);
    }

    if (stateFilter != null && stateFilter.isNotEmpty) {
      conditions.add('upload_state = ?');
      args.add(stateFilter);
    }

    final whereClause = conditions.isNotEmpty ? conditions.join(' AND ') : null;

    final maps = await db.query(
      AppConstants.manifestTableName,
      where: whereClause,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => MediaItem.fromMap(m)).toList();
  }

  Future<List<MediaItem>> getLargeFiles({int thresholdBytes = AppConstants.defaultLargeFileThresholdBytes}) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.manifestTableName,
      where: 'file_size >= ?',
      whereArgs: [thresholdBytes],
      orderBy: 'file_size DESC',
    );
    return maps.map((m) => MediaItem.fromMap(m)).toList();
  }

  /// Finds duplicates using identical content_hash OR identical (file_size, duration_seconds, width, height)
  Future<List<List<MediaItem>>> getDuplicateGroups() async {
    final db = await database;

    // 1. Group by non-null content_hash
    final hashResults = await db.rawQuery('''
      SELECT content_hash, COUNT(*) as cnt
      FROM ${AppConstants.manifestTableName}
      WHERE content_hash IS NOT NULL AND content_hash != ''
      GROUP BY content_hash
      HAVING cnt > 1
    ''');

    final groups = <List<MediaItem>>[];
    final handledIds = <String>{};

    for (final row in hashResults) {
      final hash = row['content_hash'] as String;
      final items = await db.query(
        AppConstants.manifestTableName,
        where: 'content_hash = ?',
        whereArgs: [hash],
      );
      final mediaList = items.map((m) => MediaItem.fromMap(m)).toList();
      groups.add(mediaList);
      for (final item in mediaList) {
        handledIds.add(item.localId);
      }
    }

    // 2. Group by exact file_size and duration/dimensions for items without computed hash
    final metaResults = await db.rawQuery('''
      SELECT file_size, width, height, duration_seconds, COUNT(*) as cnt
      FROM ${AppConstants.manifestTableName}
      WHERE file_size > 0
      GROUP BY file_size, width, height, duration_seconds
      HAVING cnt > 1
    ''');

    for (final row in metaResults) {
      final size = row['file_size'];
      final width = row['width'];
      final height = row['height'];
      final duration = row['duration_seconds'];

      final items = await db.query(
        AppConstants.manifestTableName,
        where: '''
          file_size = ? AND
          (width = ? OR (width IS NULL AND ? IS NULL)) AND
          (height = ? OR (height IS NULL AND ? IS NULL)) AND
          (duration_seconds = ? OR (duration_seconds IS NULL AND ? IS NULL))
        ''',
        whereArgs: [size, width, width, height, height, duration, duration],
      );

      final mediaList = items
          .map((m) => MediaItem.fromMap(m))
          .where((m) => !handledIds.contains(m.localId))
          .toList();

      if (mediaList.length > 1) {
        groups.add(mediaList);
        for (final item in mediaList) {
          handledIds.add(item.localId);
        }
      }
    }

    return groups;
  }

  /// Calculates aggregated dashboard statistics directly from the database
  Future<DashboardStats> computeDashboardStats({
    bool isPartialAccess = false,
    String currentUploadStatus = 'Idle',
    DateTime? lastScanTime,
  }) async {
    final db = await database;

    final photoCountRes = await db.rawQuery('''
      SELECT COUNT(*) as count FROM ${AppConstants.manifestTableName}
      WHERE media_type = ?
    ''', [AppMediaType.image.name]);
    final totalPhotos = Sqflite.firstIntValue(photoCountRes) ?? 0;

    final videoCountRes = await db.rawQuery('''
      SELECT COUNT(*) as count FROM ${AppConstants.manifestTableName}
      WHERE media_type = ?
    ''', [AppMediaType.video.name]);
    final totalVideos = Sqflite.firstIntValue(videoCountRes) ?? 0;

    final sizeRes = await db.rawQuery('''
      SELECT SUM(file_size) as total_size FROM ${AppConstants.manifestTableName}
    ''');
    final rawSize = sizeRes.isNotEmpty ? sizeRes.first['total_size'] : null;
    final totalSize = rawSize is num
        ? rawSize.toInt()
        : (int.tryParse(rawSize?.toString() ?? '') ?? 0);

    final uploadedRes = await db.rawQuery('''
      SELECT COUNT(*) as count, SUM(file_size) as cloud_bytes
      FROM ${AppConstants.manifestTableName}
      WHERE upload_state = ?
    ''', [UploadState.UPLOADED.name]);
    final uploadedCount = Sqflite.firstIntValue(uploadedRes) ?? 0;
    final rawCloudBytes = uploadedRes.isNotEmpty ? uploadedRes.first['cloud_bytes'] : null;
    final cloudBytes = rawCloudBytes is num
        ? rawCloudBytes.toInt()
        : (int.tryParse(rawCloudBytes?.toString() ?? '') ?? 0);

    final pendingRes = await db.rawQuery('''
      SELECT COUNT(*) as count FROM ${AppConstants.manifestTableName}
      WHERE upload_state IN (?, ?)
    ''', [UploadState.READY_TO_UPLOAD.name, UploadState.RETRY_PENDING.name]);
    final pendingCount = Sqflite.firstIntValue(pendingRes) ?? 0;

    final failedRes = await db.rawQuery('''
      SELECT COUNT(*) as count FROM ${AppConstants.manifestTableName}
      WHERE upload_state = ?
    ''', [UploadState.FAILED.name]);
    final failedCount = Sqflite.firstIntValue(failedRes) ?? 0;

    final skippedRes = await db.rawQuery('''
      SELECT COUNT(*) as count FROM ${AppConstants.manifestTableName}
      WHERE upload_state = ?
    ''', [UploadState.SKIPPED.name]);
    final skippedCount = Sqflite.firstIntValue(skippedRes) ?? 0;

    final lastSuccessRes = await db.rawQuery('''
      SELECT MAX(uploaded_at) as last_success
      FROM ${AppConstants.manifestTableName}
      WHERE upload_state = ?
    ''', [UploadState.UPLOADED.name]);
    final rawSuccess = lastSuccessRes.isNotEmpty ? lastSuccessRes.first['last_success'] : null;
    DateTime? lastSuccessfulTime;
    if (rawSuccess is num) {
      lastSuccessfulTime = DateTime.fromMillisecondsSinceEpoch(rawSuccess.toInt());
    } else if (rawSuccess is String) {
      final parsedInt = int.tryParse(rawSuccess);
      if (parsedInt != null) {
        lastSuccessfulTime = DateTime.fromMillisecondsSinceEpoch(parsedInt);
      } else {
        lastSuccessfulTime = DateTime.tryParse(rawSuccess);
      }
    }

    final duplicateGroups = await getDuplicateGroups();
    final duplicateItemsCount = duplicateGroups.fold<int>(
      0,
      (sum, g) => sum + (g.length > 1 ? g.length - 1 : 0),
    );

    final totalEligible = uploadedCount + pendingCount + failedCount;
    final completionPct = totalEligible > 0
        ? (uploadedCount / totalEligible) * 100
        : 0.0;

    return DashboardStats(
      totalAccessiblePhotos: totalPhotos,
      totalAccessibleVideos: totalVideos,
      totalMediaSize: totalSize,
      uploadedFiles: uploadedCount,
      pendingUploads: pendingCount,
      failedUploads: failedCount,
      skippedFiles: skippedCount,
      estimatedCloudStorageBytes: cloudBytes,
      backupCompletionPercentage: completionPct,
      currentUploadStatus: currentUploadStatus,
      lastSuccessfulBackupTime: lastSuccessfulTime,
      lastScanTime: lastScanTime,
      duplicateCount: duplicateItemsCount,
      isPartialAccess: isPartialAccess,
    );
  }

  Future<void> resetAllFailedToReady() async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE ${AppConstants.manifestTableName}
      SET upload_state = ?,
          error_message = NULL,
          retry_count = 0
      WHERE upload_state = ?
    ''', [UploadState.READY_TO_UPLOAD.name, UploadState.FAILED.name]);
  }

  Future<List<String>> getDistinctFolders() async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT DISTINCT folder_name
      FROM ${AppConstants.manifestTableName}
      WHERE folder_name IS NOT NULL AND folder_name != ''
      ORDER BY folder_name ASC
    ''');
    return res.map((r) => r['folder_name'] as String).toList();
  }

  Future<List<MediaItem>> getItemsByFolder(String folderName, {int limit = 500}) async {
    final db = await database;
    final res = await db.query(
      AppConstants.manifestTableName,
      where: 'folder_name = ?',
      whereArgs: [folderName],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return res.map((map) => MediaItem.fromMap(map)).toList();
  }

  /// Deletes a single media item by its localId
  Future<int> deleteMediaItem(String localId) async {
    final db = await database;
    return await db.delete(
      AppConstants.manifestTableName,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Deletes multiple media items by their localIds
  Future<int> deleteMediaItems(List<String> localIds) async {
    if (localIds.isEmpty) return 0;
    final db = await database;
    final placeholders = List.filled(localIds.length, '?').join(',');
    return await db.delete(
      AppConstants.manifestTableName,
      where: 'local_id IN ($placeholders)',
      whereArgs: localIds,
    );
  }

  /// Deletes all media items belonging to a folder
  Future<int> deleteMediaItemsByFolder(String folderName) async {
    final db = await database;
    return await db.delete(
      AppConstants.manifestTableName,
      where: 'folder_name = ?',
      whereArgs: [folderName],
    );
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete(AppConstants.manifestTableName);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
