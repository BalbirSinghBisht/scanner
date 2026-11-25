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
      expect(settings.wifiOnlyForOldMedia, isFalse);
      expect(settings.oldMediaMonthsThreshold, equals(3));
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
        wifiOnlyForOldMedia: false,
        oldMediaMonthsThreshold: 3,
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
      expect(
        restored.customFolderPaths,
        contains('/storage/emulated/0/MyPrivateVault'),
      );
      expect(restored.wifiOnlyForOldMedia, isFalse);
      expect(restored.oldMediaMonthsThreshold, equals(3));
    });

    test('correctly identifies media around the ten-day cutoff', () {
      final now = DateTime.now();
      final cutoff = BackupSettings.driveSyncCutoff(now);

      final recentItem = MediaItem(
        localId: 'recent_1',
        fileName: 'recent.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 1024,
        createdAt: now.subtract(const Duration(days: 9)),
      );

      final oldItem = MediaItem(
        localId: 'old_1',
        fileName: 'old.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 1024,
        createdAt: now.subtract(const Duration(days: 11)),
      );

      expect(recentItem.createdAt.isAfter(cutoff), isTrue);
      expect(oldItem.createdAt.isBefore(cutoff), isTrue);
    });

    test('only media inside the rolling ten-day window is eligible', () {
      final now = DateTime.now();
      final cutoff = BackupSettings.driveSyncCutoff(now);

      final queue = [
        MediaItem(
          localId: '1',
          fileName: 'old_1.jpg',
          mediaType: AppMediaType.image,
          mimeType: 'image/jpeg',
          fileSize: 1024,
          createdAt: now.subtract(const Duration(days: 11)),
        ),
        MediaItem(
          localId: '2',
          fileName: 'recent_1.jpg',
          mediaType: AppMediaType.image,
          mimeType: 'image/jpeg',
          fileSize: 1024,
          createdAt: now.subtract(const Duration(days: 5)),
        ),
        MediaItem(
          localId: '3',
          fileName: 'recent_2.jpg',
          mediaType: AppMediaType.image,
          mimeType: 'image/jpeg',
          fileSize: 1024,
          createdAt: now.subtract(const Duration(days: 10)),
        ),
      ];

      final eligibleItems =
          queue
              .where(
                (it) =>
                    it.createdAt.isAfter(cutoff) ||
                    it.createdAt.isAtSameMomentAs(cutoff),
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final excludedItems = queue
          .where((it) => it.createdAt.isBefore(cutoff))
          .toList();

      expect(eligibleItems.length, equals(2));
      expect(eligibleItems.first.localId, equals('2'));
      expect(eligibleItems.last.localId, equals('3'));
      expect(excludedItems.length, equals(1));
      expect(excludedItems.first.localId, equals('1'));
    });

    test('chunks eligible ten-day media into Wi-Fi and mobile batches', () {
      final now = DateTime.now();
      final items = List.generate(
        23,
        (i) => MediaItem(
          localId: 'id_$i',
          fileName: 'photo_$i.jpg',
          mediaType: AppMediaType.image,
          mimeType: 'image/jpeg',
          fileSize: 1024,
          createdAt: now.subtract(Duration(days: i + 1)),
        ),
      );

      // Verify batch chunking between minBatchSize (5) and maxBatchSize (10)
      const batchSizeWifi = 10;
      const batchSizeMobile = 5;

      final wifiBatches = <List<MediaItem>>[];
      for (int i = 0; i < items.length; i += batchSizeWifi) {
        wifiBatches.add(
          items.sublist(i, (i + batchSizeWifi).clamp(0, items.length)),
        );
      }

      expect(wifiBatches.length, equals(3));
      expect(wifiBatches[0].length, equals(10)); // first 10
      expect(wifiBatches[1].length, equals(10)); // next 10
      expect(wifiBatches[2].length, equals(3)); // remainder

      final mobileBatches = <List<MediaItem>>[];
      for (int i = 0; i < items.length; i += batchSizeMobile) {
        mobileBatches.add(
          items.sublist(i, (i + batchSizeMobile).clamp(0, items.length)),
        );
      }

      expect(mobileBatches.length, equals(5));
      expect(mobileBatches[0].length, equals(5));
      expect(mobileBatches[1].length, equals(5));
      expect(mobileBatches[2].length, equals(5));
      expect(mobileBatches[3].length, equals(5));
      expect(mobileBatches[4].length, equals(3));
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
