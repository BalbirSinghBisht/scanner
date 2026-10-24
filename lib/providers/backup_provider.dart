import 'dart:async';
import 'package:flutter/material.dart';
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
  bool get isPartialAccess => _scanner.isPartialAccess;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  DateTime? _lastScanTime;
  DateTime? get lastScanTime => _lastScanTime;

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
      _scanProgress = report;
      if (report.isCompleted) {
        _isScanning = false;
        await refreshData();
        // Auto-start upload as soon as files are in the dashboard
        await _autoStartUpload();
      }
      notifyListeners();
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

    // 6. Automatically capture any new data added to device gallery in real-time
    _scanner.startObservingLibraryChanges(() async {
      await startScan(forceFullScan: false);
      await _autoStartUpload();
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
      // Also scan standard device directories for downloads & camera media
      await _scanner.scanDirectDirectories();

      if (forceFullScan) {
        await _scanner.pruneDeletedItems();
      }

      _lastScanTime = DateTime.now();
      await _settingsRepo.saveLastScanTime(_lastScanTime!);
      await refreshData();
      await _autoStartUpload();
    } catch (e) {
      _errorMessage = e.toString();
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
    _stats = await _db.computeDashboardStats(
      isPartialAccess: _scanner.isPartialAccess,
      currentUploadStatus: _sync.isSyncing
          ? (_sync.isPaused ? 'Paused' : 'Uploading...')
          : 'Idle',
      lastScanTime: _lastScanTime,
    );

    _mediaItems = await _db.getAllItems(limit: 500);
    _failedItems = await _db.getFailedUploads();
    _recentUploads = await _db.getRecentUploads();

    final distinctDbFolders = await _db.getDistinctFolders();
    if (distinctDbFolders.isNotEmpty) {
      _folders = distinctDbFolders;
    } else {
      final s = _mediaItems.map((e) => e.displayFolderName).toSet().toList();
      s.sort();
      _folders = s;
    }

    final rawDupes = await _db.getDuplicateGroups();
    _duplicateGroups = rawGroupsToDuplicateGroups(rawDupes);

    notifyListeners();
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
    _scanner.stopObservingLibraryChanges();
    _scanSub?.cancel();
    _uploadSub?.cancel();
    super.dispose();
  }
}
