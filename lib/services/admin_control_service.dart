import 'dart:io';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/remote_sync_policy.dart';
import 'device_state_service.dart';

/// Spark-plan-compatible bridge using authenticated Firestore directly.
class AdminControlService {
  static final instance = AdminControlService._();
  AdminControlService._();

  String? _deviceId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _commandSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _policySub;
  RemoteSyncPolicy? _cachedPolicy;
  DateTime? _policyLoadedAt;

  Future<void> initialize() async {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    _listenForPolicy();
  }

  void _listenForPolicy() {
    if (_policySub != null) return;
    _policySub = FirebaseFirestore.instance
        .collection('config')
        .doc('syncPolicy')
        .snapshots()
        .listen(
          (snapshot) {
            _cachedPolicy = _policyFromData(snapshot.data());
            _policyLoadedAt = DateTime.now();
          },
          onError: (Object error) {
            debugPrint('[AdminControl] Policy listener unavailable: $error');
          },
        );
  }

  Future<void> _listenForCommands() async {
    if (_commandSub != null) return;
    final id = await _resolveDeviceId();
    _commandSub = FirebaseFirestore.instance
        .collection('devices')
        .doc(id)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.data()?['pendingCommand'] == 'startSync') {
              FlutterBackgroundService().invoke('triggerSync');
            }
          },
          onError: (Object error) {
            debugPrint('[AdminControl] Command listener unavailable: $error');
          },
        );
  }

  Future<String> _resolveDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      _deviceId = (await info.androidInfo).id;
    } else if (Platform.isIOS) {
      _deviceId = (await info.iosInfo).identifierForVendor;
    }
    return _deviceId ?? Platform.localHostname;
  }

  /// Reports liveness and atomically consumes a queued startSync command.
  Future<bool> heartbeatAndConsumeStart({required bool isSyncing}) async {
    try {
      await initialize();
      final user = FirebaseAuth.instance.currentUser!;
      final id = await _resolveDeviceId();
      final package = await PackageInfo.fromPlatform();
      final driveFolderName = await DeviceStateService.instance
          .getDeviceBackupFolderName();
      final ref = FirebaseFirestore.instance.collection('devices').doc(id);

      await ref.set({
        'ownerUid': user.uid,
        // Match the exact identity used at PhoneBackup/<deviceFolder> in Drive
        // so the administrator can correlate a device with its backup folder.
        'name': driveFolderName,
        'driveFolderName': driveFolderName,
        'platform': Platform.operatingSystem,
        'appVersion': package.version,
        'syncState': isSyncing ? 'syncing' : 'idle',
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _listenForCommands();

      return await FirebaseFirestore.instance.runTransaction((
        transaction,
      ) async {
        final snapshot = await transaction.get(ref);
        final command = snapshot.data()?['pendingCommand'] == 'startSync';
        if (command) {
          transaction.update(ref, {
            'pendingCommand': FieldValue.delete(),
            'commandConsumedAt': FieldValue.serverTimestamp(),
          });
        }
        return command;
      });
    } catch (e) {
      debugPrint('[AdminControl] Firestore heartbeat unavailable: $e');
      return false;
    }
  }

  Future<RemoteSyncPolicy> loadSyncPolicy() async {
    final now = DateTime.now();
    if (_cachedPolicy != null &&
        _policyLoadedAt != null &&
        now.difference(_policyLoadedAt!).inMinutes < 5) {
      return _cachedPolicy!;
    }
    try {
      await initialize();
      final snapshot = await FirebaseFirestore.instance
          .collection('config')
          .doc('syncPolicy')
          .get();
      final data = snapshot.data();
      if (data == null) return const RemoteSyncPolicy();
      _cachedPolicy = _policyFromData(data);
      _policyLoadedAt = now;
      return _cachedPolicy!;
    } catch (e) {
      debugPrint('[AdminControl] Using default 10-day sync policy: $e');
      return const RemoteSyncPolicy();
    }
  }

  RemoteSyncPolicy _policyFromData(Map<String, dynamic>? data) {
    if (data == null) return const RemoteSyncPolicy();
    final unitName = data['unit']?.toString() ?? 'days';
    return RemoteSyncPolicy(
      mode: data['mode']?.toString() ?? 'rolling',
      amount: (data['amount'] as num?)?.toInt() ?? 10,
      unit: SyncWindowUnit.values.firstWhere(
        (unit) => unit.name == unitName,
        orElse: () => SyncWindowUnit.days,
      ),
      rangeStart: (data['rangeStart'] as Timestamp?)?.toDate(),
      rangeEnd: (data['rangeEnd'] as Timestamp?)?.toDate(),
    );
  }
}
