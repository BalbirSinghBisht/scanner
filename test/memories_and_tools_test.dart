import 'package:flutter_test/flutter_test.dart';
import 'package:scanner/models/media_item.dart';
import 'package:scanner/services/memories_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MemoriesService Tests', () {
    final refDate = DateTime(2026, 11, 9, 12, 0);

    test('Finds exact On This Day memories from previous years', () {
      final items = [
        MediaItem(
          localId: 'item_2025',
          fileName: 'photo_2025.jpg',
          mediaType: AppMediaType.image,
          mimeType: 'image/jpeg',
          fileSize: 1000,
          createdAt: DateTime(2025, 11, 9, 10, 30),
        ),
        MediaItem(
          localId: 'item_2024_1',
          fileName: 'photo_2024_1.jpg',
          mediaType: AppMediaType.image,
          mimeType: 'image/jpeg',
          fileSize: 1000,
          createdAt: DateTime(2024, 11, 9, 14, 0),
        ),
        MediaItem(
          localId: 'item_2024_2',
          fileName: 'photo_2024_2.jpg',
          mediaType: AppMediaType.image,
          mimeType: 'image/jpeg',
          fileSize: 1000,
          createdAt: DateTime(2024, 11, 9, 15, 0),
        ),
        MediaItem(
          localId: 'item_current_year',
          fileName: 'today.jpg',
          mediaType: AppMediaType.image,
          mimeType: 'image/jpeg',
          fileSize: 1000,
          createdAt: DateTime(2026, 11, 9, 8, 0),
        ),
        MediaItem(
          localId: 'item_other_month',
          fileName: 'august.jpg',
          mediaType: AppMediaType.image,
          mimeType: 'image/jpeg',
          fileSize: 1000,
          createdAt: DateTime(2024, 8, 15, 12, 0),
        ),
      ];

      final memories = MemoriesService.instance.findMemories(
        items,
        referenceDate: refDate,
      );

      expect(memories.length, 2);
      expect(memories[0].yearsAgo, 1);
      expect(memories[0].title, '1 Year Ago Today');
      expect(memories[0].items.length, 1);

      expect(memories[1].yearsAgo, 2);
      expect(memories[1].title, '2 Years Ago Today');
      expect(memories[1].items.length, 2);
    });

    test('Ignores items from locked or hidden folders', () {
      final items = [
        MediaItem(
          localId: 'locked_item',
          fileName: 'secret.jpg',
          mediaType: AppMediaType.image,
          mimeType: 'image/jpeg',
          fileSize: 1000,
          createdAt: DateTime(2024, 11, 9, 10, 0),
          folderName: 'Locked',
        ),
      ];

      final memories = MemoriesService.instance.findMemories(
        items,
        referenceDate: refDate,
      );

      expect(memories.isEmpty, isTrue);
    });
  });
}

