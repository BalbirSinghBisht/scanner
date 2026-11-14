import 'package:flutter_test/flutter_test.dart';
import 'package:scanner/models/backup_settings.dart';
import 'package:scanner/models/duplicate_group.dart';
import 'package:scanner/models/media_item.dart';

void main() {
  group('BackupSettings Tests', () {
    test('default settings enable auto backup out of the box', () {
      const settings = BackupSettings();
      expect(settings.userConsentGiven, isTrue);
      expect(settings.autoBackupEnabled, isTrue);
      expect(settings.wifiOnly, isFalse);
      expect(settings.backupPhotos, isTrue);
      expect(settings.backupVideos, isTrue);
      expect(settings.localOnlyMode, isFalse);
      expect(settings.syncLockedFolders, isTrue);
      expect(settings.customFolderPaths, isEmpty);
      expect(settings.wifiOnlyForOldMedia, isTrue);
      expect(settings.oldMediaMonthsThreshold, equals(6));
    });

    test('serializes and deserializes correctly', () {
      const original = BackupSettings(
        autoBackupEnabled: true,
        userConsentGiven: true,
        wifiOnly: false,
        backupPhotos: true,
        backupVideos: false,
        minBatteryThreshold: 35,
        chargingOnly: true,
        maxVideoSizeBytes: 104857600,
        localOnlyMode: true,
        syncLockedFolders: true,
        customFolderPaths: ['/storage/emulated/0/MyPrivateVault'],
        wifiOnlyForOldMedia: true,
        oldMediaMonthsThreshold: 6,
      );

      final map = original.toMap();
      final restored = BackupSettings.fromMap(map);

      expect(restored.autoBackupEnabled, isTrue);
      expect(restored.userConsentGiven, isTrue);
      expect(restored.wifiOnly, isFalse);
      expect(restored.backupVideos, isFalse);
      expect(restored.minBatteryThreshold, equals(35));
      expect(restored.chargingOnly, isTrue);
      expect(restored.maxVideoSizeBytes, equals(104857600));
      expect(restored.localOnlyMode, isTrue);
      expect(restored.syncLockedFolders, isTrue);
      expect(restored.customFolderPaths, contains('/storage/emulated/0/MyPrivateVault'));
      expect(restored.wifiOnlyForOldMedia, isTrue);
      expect(restored.oldMediaMonthsThreshold, equals(6));
    });

    test('correctly identifies media older and newer than threshold cutoff', () {
      final now = DateTime.now();
      const settings = BackupSettings(
        wifiOnlyForOldMedia: true,
        oldMediaMonthsThreshold: 6,
      );

      final cutoff = DateTime(
        now.year,
        now.month - settings.oldMediaMonthsThreshold,
        now.day,
        now.hour,
        now.minute,
        now.second,
      );

      final recentItem = MediaItem(
        localId: 'recent_1',
        fileName: 'recent.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 1024,
        createdAt: now.subtract(const Duration(days: 30)),
      );

      final oldItem = MediaItem(
        localId: 'old_1',
        fileName: 'old.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 1024,
        createdAt: now.subtract(const Duration(days: 220)),
      );

      expect(recentItem.createdAt.isAfter(cutoff), isTrue);
      expect(oldItem.createdAt.isBefore(cutoff), isTrue);
    });
  });

  group('DuplicateGroup Tests', () {
    test('calculates potential storage savings correctly', () {
      final item1 = MediaItem(
        localId: '1',
        fileName: 'photo_original.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 5000000,
        createdAt: DateTime.now(),
        contentHash: 'hash_abc',
      );
      final item2 = MediaItem(
        localId: '2',
        fileName: 'photo_copy.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 5000000,
        createdAt: DateTime.now(),
        contentHash: 'hash_abc',
      );

      final group = DuplicateGroup(
        signature: 'hash_abc',
        items: [item1, item2],
      );

      expect(group.totalSizeBytes, equals(10000000));
      // Savings = keeping 1 copy, savings = other copy (5,000,000)
      expect(group.potentialSavingsBytes, equals(5000000));
      expect(group.formattedPotentialSavings, contains('MB'));
    });
  });
}
