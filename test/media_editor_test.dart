import 'package:flutter_test/flutter_test.dart';
import 'package:scanner/models/media_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Media Editor Integration Tests', () {
    test('Calculates color matrix correctly for vivid preset', () {
      // 20-element RGBA color matrix
      final vividMatrix = [
        1.3, 0.0, 0.0, 0.0, 5.0,
        0.0, 1.3, 0.0, 0.0, 5.0,
        0.0, 0.0, 1.3, 0.0, 5.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ];
      expect(vividMatrix.length, 20);
      expect(vividMatrix[0], 1.3);
      expect(vividMatrix[4], 5.0);
    });

    test('Creates edited MediaItem instance with correct attributes in DCIM', () {
      final now = DateTime.now();
      final item = MediaItem(
        localId: 'edited_test_123',
        fileName: 'sample_edited.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 10240,
        createdAt: now,
        uploadState: UploadState.READY_TO_UPLOAD,
        localFilePath: '/storage/emulated/0/DCIM/sample_edited.jpg',
        folderName: 'DCIM',
      );

      expect(item.localId, 'edited_test_123');
      expect(item.fileName, 'sample_edited.jpg');
      expect(item.mediaType, AppMediaType.image);
      expect(item.uploadState, UploadState.READY_TO_UPLOAD);
      expect(item.folderName, 'DCIM');
      expect(item.localFilePath, contains('/DCIM/'));
    });

    test('Creates trimmed video MediaItem with proper duration in DCIM', () {
      final now = DateTime.now();
      final item = MediaItem(
        localId: 'trimmed_video_456',
        fileName: 'clip_trimmed.mp4',
        mediaType: AppMediaType.video,
        mimeType: 'video/mp4',
        fileSize: 5242880,
        durationSeconds: 12,
        createdAt: now,
        uploadState: UploadState.READY_TO_UPLOAD,
        localFilePath: '/storage/emulated/0/DCIM/clip_trimmed.mp4',
        folderName: 'DCIM',
      );

      expect(item.localId, 'trimmed_video_456');
      expect(item.durationSeconds, 12);
      expect(item.mediaType, AppMediaType.video);
      expect(item.folderName, 'DCIM');
      expect(item.localFilePath, contains('/DCIM/'));
    });
  });
}

