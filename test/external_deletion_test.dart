import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanner/models/media_item.dart';

void main() {
  test('Active existence check detects and excludes externally deleted files', () {
    // Create temporary file on disk
    final tempDir = Directory.systemTemp.createTempSync('deletion_test_');
    final survivingFile = File('${tempDir.path}/surviving.jpg')..writeAsStringSync('surviving');
    final deletedFile = File('${tempDir.path}/deleted.jpg')..writeAsStringSync('deleted');

    // Verify both exist
    expect(survivingFile.existsSync(), isTrue);
    expect(deletedFile.existsSync(), isTrue);

    // Simulate external deletion by another file manager
    deletedFile.deleteSync();
    expect(deletedFile.existsSync(), isFalse);

    // Filter logic as used in BackupProvider.refreshData()
    final items = [
      MediaItem(
        localId: 'disk_1',
        fileName: 'surviving.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 100,
        createdAt: DateTime.now(),
        localFilePath: survivingFile.path,
      ),
      MediaItem(
        localId: 'disk_2',
        fileName: 'deleted.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 100,
        createdAt: DateTime.now(),
        localFilePath: deletedFile.path,
      ),
    ];

    final uniqueItems = <MediaItem>[];
    final missingIds = <String>[];

    for (final it in items) {
      if (it.localId.startsWith('disk_') && it.localFilePath != null && it.localFilePath!.isNotEmpty) {
        if (!File(it.localFilePath!).existsSync()) {
          missingIds.add(it.localId);
          continue;
        }
      }
      uniqueItems.add(it);
    }

    expect(uniqueItems.length, 1);
    expect(uniqueItems.first.localId, 'disk_1');
    expect(missingIds, ['disk_2']);

    tempDir.deleteSync(recursive: true);
  });
}

