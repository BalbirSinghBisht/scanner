import 'package:flutter_test/flutter_test.dart';
import 'package:scanner/models/media_item.dart';

void main() {
  group('Prune & Folder Deletion Tests', () {
    test('groups items by display folder and cleans up when items are pruned', () {
      final item1 = MediaItem(
        localId: 'id_1',
        fileName: 'photo1.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 1024,
        createdAt: DateTime(2026, 1, 1),
        folderName: 'Trip2026',
      );

      final item2 = MediaItem(
        localId: 'id_2',
        fileName: 'photo2.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 2048,
        createdAt: DateTime(2026, 1, 2),
        folderName: 'Trip2026',
      );

      final item3 = MediaItem(
        localId: 'id_3',
        fileName: 'camera1.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 4096,
        createdAt: DateTime(2026, 1, 3),
        folderName: 'Camera',
      );

      List<MediaItem> allItems = [item1, item2, item3];

      // Folder grouping simulation
      Map<String, List<MediaItem>> groupByFolder(List<MediaItem> items) {
        final map = <String, List<MediaItem>>{};
        for (final item in items) {
          map.putIfAbsent(item.displayFolderName, () => []).add(item);
        }
        return map;
      }

      var folders = groupByFolder(allItems);
      expect(folders.keys, contains('Trip2026'));
      expect(folders.keys, contains('Camera'));
      expect(folders['Trip2026']!.length, equals(2));

      // Simulate external deletion of album "Trip2026"
      // prune removes items with localId 'id_1' and 'id_2'
      final toDelete = {'id_1', 'id_2'};
      allItems = allItems.where((it) => !toDelete.contains(it.localId)).toList();

      folders = groupByFolder(allItems);
      expect(folders.containsKey('Trip2026'), isFalse);
      expect(folders.keys, contains('Camera'));
      expect(allItems.length, equals(1));
    });

    test('displayFolderName correctly falls back to parent path or Camera/Videos', () {
      final diskItem = MediaItem(
        localId: 'disk_123',
        fileName: 'my_doc.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 500,
        createdAt: DateTime(2026, 1, 1),
        localFilePath: '/storage/emulated/0/Pictures/Screenshots/my_doc.jpg',
      );

      expect(diskItem.displayFolderName, equals('Screenshots'));

      final noFolderItem = MediaItem(
        localId: 'disk_456',
        fileName: 'movie.mp4',
        mediaType: AppMediaType.video,
        mimeType: 'video/mp4',
        fileSize: 15000,
        createdAt: DateTime(2026, 1, 1),
      );

      expect(noFolderItem.displayFolderName, equals('Videos'));
    });
  });
}
