import 'dart:io';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'device_state_service.dart';

/// Spark-plan-compatible bridge using authenticated Firestore directly.
class AdminControlService {
  static final instance = AdminControlService._();
  AdminControlService._();

  String? _deviceId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _commandSub;

  Future<void> initialize() async {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    await _listenForCommands();
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
}
