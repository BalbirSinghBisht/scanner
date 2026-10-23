import 'dart:async';
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
        local_file_path TEXT
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
  }

  /// Recovers any interrupted transfers from previous app lifecycle.
  /// If an item was in 'UPLOADING' state when the app was closed or crashed,
  /// it is reverted to 'READY_TO_UPLOAD' or 'RETRY_PENDING' so it can resume cleanly.
  Future<int> recoverInterruptedUploads() async {
    final db = await database;
    return await db.rawUpdate('''
      UPDATE ${AppConstants.manifestTableName}
      SET upload_state = ?,
          error_message = ?
      WHERE upload_state = ?
    ''', [
      UploadState.RETRY_PENDING.name,
      'Interrupted by app termination or process exit. Queued for resume.',
      UploadState.UPLOADING.name,
    ]);
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
    final totalSize = (sizeRes.first['total_size'] as num?)?.toInt() ?? 0;

    final uploadedRes = await db.rawQuery('''
      SELECT COUNT(*) as count, SUM(file_size) as cloud_bytes
      FROM ${AppConstants.manifestTableName}
      WHERE upload_state = ?
    ''', [UploadState.UPLOADED.name]);
    final uploadedCount = Sqflite.firstIntValue(uploadedRes) ?? 0;
    final cloudBytes = (uploadedRes.first['cloud_bytes'] as num?)?.toInt() ?? 0;

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
    final lastSuccessVal = lastSuccessRes.first['last_success'] as num?;
    final lastSuccessfulTime = lastSuccessVal != null
        ? DateTime.fromMillisecondsSinceEpoch(lastSuccessVal.toInt())
        : null;

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

  Future<void> clearAll() async {
    final db = await database;
    await db.delete(AppConstants.manifestTableName);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
