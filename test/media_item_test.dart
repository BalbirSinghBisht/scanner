import 'package:flutter_test/flutter_test.dart';
import 'package:scanner/models/media_item.dart';

void main() {
  group('MediaItem Tests', () {
    test('computes target folder path by media creation date', () {
      final photo = MediaItem(
        localId: '101',
        fileName: 'IMG_20260115_091522.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 2048576,
        createdAt: DateTime(2026, 1, 15, 9, 15, 22),
      );

      expect(photo.computeTargetFolderPath(), equals('PhoneBackup/Photos/2026/01'));

      final video = MediaItem(
        localId: '102',
        fileName: 'VID_20261102_143000.mp4',
        mediaType: AppMediaType.video,
        mimeType: 'video/mp4',
        fileSize: 52428800,
        createdAt: DateTime(2026, 11, 2, 14, 30, 0),
      );

      expect(video.computeTargetFolderPath(), equals('PhoneBackup/Videos/2026/11'));
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
  });
}
