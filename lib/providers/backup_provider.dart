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

  Future<void> init() async {
    // 1. Recover any interrupted records from previous runs
    await _db.recoverInterruptedUploads();

    // 2. Load last scan timestamp
    _lastScanTime = await _settingsRepo.getLastScanTime();

    // 3. Listen to scanning progress
    _scanSub = _scanner.scanProgressStream.listen((report) {
      _scanProgress = report;
      if (report.isCompleted) {
        _isScanning = false;
        refreshData();
      }
      notifyListeners();
    });

    // 4. Listen to upload progress
    _uploadSub = _sync.progressStream.listen((event) {
      _currentUploadEvent = event;
      if (event == null || event.progress >= 1.0) {
        // Refresh counts when upload ends or finishes
        _refreshStatsOnly();
      }
      notifyListeners();
    });

    // 5. Initial data load
    await refreshData();
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

      _lastScanTime = DateTime.now();
      await _settingsRepo.saveLastScanTime(_lastScanTime!);
      await refreshData();
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

  /// Refreshes all cached lists and dashboard statistics from SQLite manifest
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

    final rawDupes = await _db.getDuplicateGroups();
    _duplicateGroups = rawGroupsToDuplicateGroups(rawDupes);

    notifyListeners();
  }

  Future<void> _refreshStatsOnly() async {
    _stats = await _db.computeDashboardStats(
      isPartialAccess: _scanner.isPartialAccess,
      currentUploadStatus: _sync.isSyncing
          ? (_sync.isPaused ? 'Paused' : 'Uploading...')
          : 'Idle',
      lastScanTime: _lastScanTime,
    );
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
    _scanSub?.cancel();
    _uploadSub?.cancel();
    super.dispose();
  }
}
