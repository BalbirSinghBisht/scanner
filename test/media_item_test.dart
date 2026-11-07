import 'package:flutter_test/flutter_test.dart';
import 'package:scanner/models/media_item.dart';

void main() {
  group('MediaItem Tests', () {
    test('computes target folder path by folder name and device', () {
      final photo = MediaItem(
        localId: '101',
        fileName: 'IMG_20260115_091522.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 2048576,
        createdAt: DateTime(2026, 1, 15, 9, 15, 22),
        folderName: 'Camera',
      );

      expect(photo.computeTargetFolderPath(deviceFolder: 'MyPhone'), equals('PhoneBackup/MyPhone/Camera'));

      final video = MediaItem(
        localId: '102',
        fileName: 'VID_20261102_143000.mp4',
        mediaType: AppMediaType.video,
        mimeType: 'video/mp4',
        fileSize: 52428800,
        createdAt: DateTime(2026, 11, 2, 14, 30, 0),
        folderName: 'WhatsApp Videos',
      );

      expect(video.computeTargetFolderPath(deviceFolder: 'MyPhone'), equals('PhoneBackup/MyPhone/WhatsApp Videos'));
    });

    test('serializes to map and deserializes back correctly', () {
      final original = MediaItem(
        localId: 'item_42',
        fileName: 'vacation.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 4500000,
        width: 4000,
        height: 3000,
        createdAt: DateTime(2026, 5, 20, 10, 0, 0),
        uploadState: UploadState.READY_TO_UPLOAD,
        contentHash: 'a1b2c3d4e5f6',
      );

      final map = original.toMap();
      final restored = MediaItem.fromMap(map);

      expect(restored.localId, equals(original.localId));
      expect(restored.fileName, equals(original.fileName));
      expect(restored.mediaType, equals(original.mediaType));
      expect(restored.fileSize, equals(original.fileSize));
      expect(restored.width, equals(4000));
      expect(restored.height, equals(3000));
      expect(restored.contentHash, equals('a1b2c3d4e5f6'));
      expect(restored.uploadState, equals(UploadState.READY_TO_UPLOAD));
    });

    test('formatted size output returns appropriate units', () {
      final itemKb = MediaItem(
        localId: '1',
        fileName: 'test.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 153600, // 150 KB
        createdAt: DateTime.now(),
      );
      expect(itemKb.formattedSize, contains('KB'));

      final itemMb = MediaItem(
        localId: '2',
        fileName: 'video.mp4',
        mediaType: AppMediaType.video,
        mimeType: 'video/mp4',
        fileSize: 104857600, // 100 MB
        createdAt: DateTime.now(),
      );
      expect(itemMb.formattedSize, contains('MB'));
    });

    test('correctly identifies locked and private folders and formats display names', () {
      final lockedItem = MediaItem(
        localId: 'disk_1',
        fileName: 'secret.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 200000,
        createdAt: DateTime.now(),
        localFilePath: '/storage/emulated/0/Pictures/.private/secret.jpg',
        folderName: '.private',
      );

      expect(lockedItem.isLockedFolder, isTrue);
      expect(lockedItem.displayFolderName, equals('Private (Locked)'));
      expect(lockedItem.computeTargetFolderPath(deviceFolder: 'MyDevice'),
          equals('PhoneBackup/MyDevice/Private (Locked)'));

      final secretItem = MediaItem(
        localId: 'disk_2',
        fileName: 'doc.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 300000,
        createdAt: DateTime.now(),
        localFilePath: '/storage/emulated/0/.locked/doc.jpg',
        folderName: '.locked',
      );

      expect(secretItem.isLockedFolder, isTrue);
      expect(secretItem.displayFolderName, equals('Locked Folder'));

      final regularItem = MediaItem(
        localId: 'disk_3',
        fileName: 'photo.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 150000,
        createdAt: DateTime.now(),
        localFilePath: '/storage/emulated/0/DCIM/Camera/photo.jpg',
        folderName: 'Camera',
      );

      expect(regularItem.isLockedFolder, isFalse);
      expect(regularItem.displayFolderName, equals('Camera'));
    });

    test('silent sync filters out locked folder items from UI list while preserving for sync', () {
      final items = [
        MediaItem(
          localId: '1',
          fileName: 'camera_1.jpg',
          mediaType: AppMediaType.image,
          mimeType: 'image/jpeg',
          fileSize: 1000,
          createdAt: DateTime.now(),
          folderName: 'Camera',
          uploadState: UploadState.READY_TO_UPLOAD,
        ),
        MediaItem(
          localId: '2',
          fileName: 'vault_photo.jpg',
          mediaType: AppMediaType.image,
          mimeType: 'image/jpeg',
          fileSize: 2000,
          createdAt: DateTime.now(),
          folderName: '.private',
          localFilePath: '/storage/emulated/0/.private/vault_photo.jpg',
          uploadState: UploadState.READY_TO_UPLOAD,
        ),
      ];

      // UI filtering hides locked folder
      final visibleItems = items.where((it) => !it.isLockedFolder).toList();
      expect(visibleItems.length, equals(1));
      expect(visibleItems.first.fileName, equals('camera_1.jpg'));

      // Sync queue retains all items including locked folder
      final syncQueueItems = items.where((it) => it.uploadState == UploadState.READY_TO_UPLOAD).toList();
      expect(syncQueueItems.length, equals(2));
    });
  });
}
