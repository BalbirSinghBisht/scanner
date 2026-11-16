import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/expiring_media_item.dart';
import 'database_helper.dart';
import 'media_scanner_service.dart';

class ExpiringMediaService extends ChangeNotifier {
  static final ExpiringMediaService instance = ExpiringMediaService._internal();

  ExpiringMediaService._internal();

  final DatabaseHelper _db = DatabaseHelper.instance;
  final Map<String, ExpiringMediaItem> _expiringMap = {};
  Timer? _countdownTimer;
  bool _isPurging = false;
  void Function(String localId)? onItemPurged;

  Map<String, ExpiringMediaItem> get expiringMap => Map.unmodifiable(_expiringMap);
  int get count => _expiringMap.length;

  Future<void> init() async {
    try {
      final items = await _db.getAllExpiring();
      _expiringMap.clear();
      for (final it in items) {
        _expiringMap[it.localId] = it;
      }
      notifyListeners();

      // Check for and purge any already-expired items
      await purgeExpired();

      // Start periodic countdown & watchdog timer (runs every 30s)
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        await purgeExpired();
        notifyListeners();
      });
    } catch (e) {
      debugPrint('[ExpiringMediaService] Error during init: $e');
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  bool isExpiring(String localId) => _expiringMap.containsKey(localId);

  ExpiringMediaItem? getExpiry(String localId) => _expiringMap[localId];

  Future<void> setExpiry(String localId, Duration duration) async {
    final now = DateTime.now();
    final expiresAt = now.add(duration);
    final item = ExpiringMediaItem(
      localId: localId,
      expiresAt: expiresAt,
      createdAt: now,
      durationSeconds: duration.inSeconds,
    );

    _expiringMap[localId] = item;
    notifyListeners();

    try {
      await _db.insertOrUpdateExpiring(item);
    } catch (e) {
      debugPrint('[ExpiringMediaService] Error setting expiry: $e');
    }
  }

  Future<void> removeExpiry(String localId) async {
    if (!_expiringMap.containsKey(localId)) return;
    _expiringMap.remove(localId);
    notifyListeners();

    try {
      await _db.removeExpiring(localId);
    } catch (e) {
      debugPrint('[ExpiringMediaService] Error removing expiry: $e');
    }
  }

  /// Scans for and permanently purges items whose expiry timestamp has passed
  Future<int> purgeExpired() async {
    if (_isPurging) return 0;
    _isPurging = true;

    int purgedCount = 0;
    try {
      final now = DateTime.now();
      final expiredLocalIds = <String>[];

      for (final entry in _expiringMap.entries) {
        if (now.isAfter(entry.value.expiresAt)) {
          expiredLocalIds.add(entry.key);
        }
      }

      if (expiredLocalIds.isNotEmpty) {
        for (final localId in expiredLocalIds) {
          try {
            // Strictly delete ONLY from local physical device storage to free up phone memory.
            // Google Drive files are NEVER touched or deleted.
            await MediaScannerService.instance.deleteMediaFromDevice(localId);
            await _db.removeExpiring(localId);
            await _db.deleteMediaItem(localId);
            _expiringMap.remove(localId);
            purgedCount++;
            onItemPurged?.call(localId);
            debugPrint('[ExpiringMediaService] Auto-purged expired clutter from local device: $localId (Drive cloud backup is completely preserved)');
          } catch (e) {
            debugPrint('[ExpiringMediaService] Error purging $localId: $e');
          }
        }
        notifyListeners();
      }
    } finally {
      _isPurging = false;
    }
    return purgedCount;
  }
}

