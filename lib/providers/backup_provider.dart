import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/backup_settings.dart';
import '../models/dashboard_stats.dart';
import '../models/duplicate_group.dart';
import '../models/media_item.dart';
import '../services/backup_sync_service.dart';
import '../services/database_helper.dart';
import '../services/media_analysis_service.dart';
import '../services/media_scanner_service.dart';
import '../services/settings_repository.dart';

class BackupProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final MediaScannerService _scanner = MediaScannerService.instance;
  final MediaAnalysisService _analysis = MediaAnalysisService.instance;
  final BackupSyncService _sync = BackupSyncService.instance;
  final SettingsRepository _settingsRepo = SettingsRepository.instance;

  StreamSubscription<ScanProgressReport>? _scanSub;
  StreamSubscription<UploadProgressEvent?>? _uploadSub;
  Timer? _foregroundPollingTimer;
  static const MethodChannel _nativeChannel = MethodChannel('com.mediabackup.scanner/device_settings');

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  ScanProgressReport? _scanProgress;
  ScanProgressReport? get scanProgress => _scanProgress;

  UploadProgressEvent? _currentUploadEvent;
  UploadProgressEvent? get currentUploadEvent => _currentUploadEvent;

  DashboardStats _stats = const DashboardStats();
  DashboardStats get stats => _stats;

  AnalysisReport? _analysisReport;
  AnalysisReport? get analysisReport => _analysisReport;

  List<MediaItem> _mediaItems = [];
  List<MediaItem> get mediaItems => _mediaItems;

  List<MediaItem> _failedItems = [];
  List<MediaItem> get failedItems => _failedItems;

  List<MediaItem> _recentUploads = [];
  List<MediaItem> get recentUploads => _recentUploads;

  List<DuplicateGroup> _duplicateGroups = [];
  List<DuplicateGroup> get duplicateGroups => _duplicateGroups;

  bool get isSyncing => _sync.isSyncing;
  bool get isPaused => _sync.isPaused;
  bool get isWaitingForNetwork => _sync.isWaitingForNetwork;
  bool get isPartialAccess => _scanner.isPartialAccess;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  DateTime? _lastScanTime;
  DateTime? get lastScanTime => _lastScanTime;
  DateTime? _lastPruneTime;

  List<String> _folders = [];
  List<String> get folders => _folders;

  bool get hasAuthError => _sync.hasAuthError;
  String? get authErrorMessage => _sync.authErrorMessage;

  Future<void> init() async {
    // 1. Recover interrupted records and reset failed items so they are retried
    await _db.recoverInterruptedUploads();
    await _db.resetAllFailedToReady();

    // 2. Load last scan timestamp
    _lastScanTime = await _settingsRepo.getLastScanTime();

    // 3. Listen to scanning progress
    _scanSub = _scanner.scanProgressStream.listen((report) async {
      if (report.isCompleted) {
        _isScanning = false;
        await refreshData();
        // Auto-start upload as soon as files are in the dashboard
        await _autoStartUpload();
        notifyListeners();
      }
    });

    // 4. Listen to upload progress (only notify on completion or failure in-place to prevent UI flickering)
    _uploadSub = _sync.progressStream.listen((event) async {
      _currentUploadEvent = event;
      if (event == null) {
        // Sync finished or stopped
        _failedItems = await _db.getFailedUploads();
        notifyListeners();
      } else if (event.progress >= 1.0) {
        // Update item in-place so GridView doesn't rebuild or flicker
        final idx = _mediaItems.indexWhere((it) => it.localId == event.item.localId);
        if (idx != -1) {
          _mediaItems[idx] = _mediaItems[idx].copyWith(uploadState: UploadState.UPLOADED);
        }
        _failedItems = await _db.getFailedUploads();
        notifyListeners();
      } else if (event.statusMessage.startsWith('Failed') || event.statusMessage.contains('Expired')) {
        final idx = _mediaItems.indexWhere((it) => it.localId == event.item.localId);
        if (idx != -1) {
          _mediaItems[idx] = _mediaItems[idx].copyWith(uploadState: UploadState.FAILED);
        }
        _failedItems = await _db.getFailedUploads();
        notifyListeners();
      }
    });

    // 5. Initial data load
    await refreshData();

    // If media items already exist and not syncing, automatically start uploading
    if (_mediaItems.isNotEmpty && !_sync.isSyncing) {
      _autoStartUpload();
    }

    // 6. Listen to native Android MediaStore & camera change events
    _nativeChannel.setMethodCallHandler((call) async {
      if (call.method == 'onMediaChanged') {
        debugPrint('[BackupProvider] Native onMediaChanged event received! Starting incremental scan and auto-upload...');
        await startScan(forceFullScan: false);
        await _autoStartUpload();
      }
    });

    // 7. Automatically capture any new data added to device gallery in real-time
    _scanner.startObservingLibraryChanges(() async {
      await startScan(forceFullScan: false);
      await _autoStartUpload();
    });

    // 8. Active foreground watchdog to ensure newly taken photos/videos sync immediately
    _foregroundPollingTimer?.cancel();
    _foregroundPollingTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (!_isScanning && !_sync.isSyncing) {
        await startScan(forceFullScan: false);
      }
    });
  }

  Future<void> _autoStartUpload() async {
    try {
      final settings = await _settingsRepo.loadSettings();
      if (!_sync.isSyncing) {
        await startBackup(settings, isManual: true);
      }
    } catch (_) {}
  }

  /// Triggers media library scanning
  Future<void> startScan({bool forceFullScan = false}) async {
    if (_isScanning) return;
    _isScanning = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _scanner.scanMedia(
        forceFullScan: forceFullScan,
        scanSince: forceFullScan ? null : _lastScanTime,
      );

      // Prune deleted items on full scan or periodically (every 10 seconds) so external file deletions reflect immediately
      final now = DateTime.now();
      if (forceFullScan || _lastPruneTime == null || now.difference(_lastPruneTime!).inSeconds >= 10) {
        await _scanner.pruneDeletedItems();
        _lastPruneTime = now;
      }

      _lastScanTime = DateTime.now();
      await _settingsRepo.saveLastScanTime(_lastScanTime!);
      await refreshData();
      await _autoStartUpload();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Scan error: $e');
      await refreshData();
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Runs media analysis
  Future<void> runAnalysis() async {
    try {
      _analysisReport = await _analysis.runAnalysis();
      _duplicateGroups = _analysisReport?.duplicateGroups ?? [];
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Analysis error: $e';
      notifyListeners();
    }
  }

  /// Starts or resumes automatic backup sync
  Future<void> startBackup(BackupSettings settings, {bool isManual = false}) async {
    await _sync.startSync(settings: settings, isManualTrigger: isManual);
    await refreshData();
  }

  void pauseBackup() {
    _sync.pause();
    notifyListeners();
  }

  void resumeBackup(BackupSettings settings) {
    _sync.resume(settings);
    notifyListeners();
  }

  Future<void> retryFailedUploads(BackupSettings settings) async {
    await _sync.retryFailedUploads(settings);
    await refreshData();
  }

  /// Refreshes all cached lists and dashboard statistics from SQLite manifest (Read-Only)
  Future<void> refreshData() async {
    // Purge any disk vs MediaStore duplicates in SQLite manifest
    try {
      await _db.deduplicateManifest();
    } catch (_) {}

    _stats = await _db.computeDashboardStats(
      isPartialAccess: _scanner.isPartialAccess,
      currentUploadStatus: _sync.isSyncing
          ? (_sync.isPaused ? 'Paused' : 'Uploading...')
          : 'Idle',
      lastScanTime: _lastScanTime,
    );

    final rawItems = await _db.getAllItems(limit: 500);
    
    // Strict zero-duplication & file existence guarantee
    final seen = <String>{};
    final uniqueItems = <MediaItem>[];
    final missingIds = <String>[];

    for (final it in rawItems) {
      if (it.isLockedFolder) continue;

      // Active file existence check: if recorded on disk, verify file actually exists
      if (it.localFilePath != null && it.localFilePath!.isNotEmpty) {
        if (!File(it.localFilePath!).existsSync()) {
          missingIds.add(it.localId);
          continue;
        }
      }

      final key = (it.localFilePath != null && it.localFilePath!.isNotEmpty)
          ? it.localFilePath!
          : it.fileName;
      if (seen.add(key)) {
        uniqueItems.add(it);
      }
    }
    _mediaItems = uniqueItems;

    // Asynchronously delete missing items from manifest & thumbnail cache
    if (missingIds.isNotEmpty) {
      _db.deleteMediaItems(missingIds);
      for (final id in missingIds) {
        _scanner.invalidateCache(id);
      }
    }

    _failedItems = (await _db.getFailedUploads()).where((it) => !it.isLockedFolder).toList();
    _recentUploads = (await _db.getRecentUploads()).where((it) => !it.isLockedFolder).toList();

    final distinctDbFolders = await _db.getDistinctFolders();
    _folders = distinctDbFolders
        .where((f) =>
            !f.startsWith('.') &&
            !f.toLowerCase().contains('private') &&
            !f.toLowerCase().contains('locked') &&
            !f.toLowerCase().contains('secret') &&
            !f.toLowerCase().contains('vault'))
        .toList();

    notifyListeners();
  }

  /// Actively synchronizes the in-memory and database state with the filesystem:
  /// - Prunes files deleted by external apps or file managers
  /// - Refreshes UI immediately so deleted tiles vanish
  /// - Scans for any newly added files
  Future<void> syncWithFileSystem() async {
    try {
      await _scanner.pruneDeletedItems();
      _lastPruneTime = DateTime.now();
      await refreshData();
      if (!_isScanning && !_sync.isSyncing) {
        await startScan(forceFullScan: false);
      }
    } catch (e) {
      debugPrint('[BackupProvider] syncWithFileSystem error: $e');
      await refreshData();
    }
  }

  /// Deletes a media item from the device storage and immediately removes it from the UI
  Future<bool> deleteMediaItem(MediaItem item) async {
    final success = await _scanner.deleteMediaFromDevice(item.localId);
    _mediaItems.removeWhere((it) => it.localId == item.localId);
    _failedItems.removeWhere((it) => it.localId == item.localId);
    _recentUploads.removeWhere((it) => it.localId == item.localId);
    notifyListeners();
    await refreshData();
    return success;
  }

  /// Removes an item from in-memory list when detected missing
  void removeMediaItemLocally(String localId) {
    _mediaItems.removeWhere((it) => it.localId == localId);
    notifyListeners();
  }

  static List<DuplicateGroup> rawGroupsToDuplicateGroups(
    List<List<MediaItem>> raw,
  ) {
    final list = <DuplicateGroup>[];
    for (final group in raw) {
      if (group.length > 1) {
        final sig = group.first.contentHash ??
            '${group.first.fileSize}_${group.first.width}x${group.first.height}';
        list.add(DuplicateGroup(signature: sig, items: group));
      }
    }
    return list;
  }

  Future<void> resetAllData() async {
    _sync.stop();
    await _db.clearAll();
    _mediaItems.clear();
    _failedItems.clear();
    _recentUploads.clear();
    _duplicateGroups.clear();
    _analysisReport = null;
    _stats = const DashboardStats();
    notifyListeners();
  }

  @override
  void dispose() {
    _foregroundPollingTimer?.cancel();
    _scanner.stopObservingLibraryChanges();
    _scanSub?.cancel();
    _uploadSub?.cancel();
    super.dispose();
  }
}
