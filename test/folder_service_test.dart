import 'package:flutter_test/flutter_test.dart';
import 'package:scanner/models/media_item.dart';
import 'package:scanner/services/folder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('FolderService & Move Data Tests', () {
    test('Create and manage custom albums', () async {
      final service = FolderService.instance;
      await service.init();

      // Disallow empty or reserved names
      expect(await service.createAlbum(''), isFalse);
      expect(await service.createAlbum('   '), isFalse);
      expect(await service.createAlbum('.private'), isFalse);
      expect(await service.createAlbum('Private'), isFalse);
      expect(await service.createAlbum('vault'), isFalse);

      // Successfully create albums
      expect(await service.createAlbum('Summer Trip 2026'), isTrue);
      expect(await service.createAlbum('Receipts'), isTrue);

      expect(service.customAlbums, contains('Summer Trip 2026'));
      expect(service.customAlbums, contains('Receipts'));

      // Delete an album
      expect(await service.deleteAlbum('Receipts'), isTrue);
      expect(service.customAlbums, isNot(contains('Receipts')));
    });

    test('Moving item between folders updates folderName and Google Drive sync target path', () {
      final item = MediaItem(
        localId: 'img_001',
        fileName: 'nature.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 3145728,
        createdAt: DateTime(2026, 3, 10),
        folderName: 'Camera',
      );

      expect(item.displayFolderName, equals('Camera'));
      expect(item.computeTargetFolderPath(deviceFolder: 'Galaxy_S25'),
          equals('PhoneBackup/Galaxy_S25/Camera'));

      // Move to "Vacation 2026"
      final movedItem = item.copyWith(folderName: 'Vacation 2026');
      expect(movedItem.displayFolderName, equals('Vacation 2026'));
      expect(movedItem.computeTargetFolderPath(deviceFolder: 'Galaxy_S25'),
          equals('PhoneBackup/Galaxy_S25/Vacation 2026'));

      // Move to "Screenshots"
      final screenshotItem = movedItem.copyWith(folderName: 'Screenshots');
      expect(screenshotItem.displayFolderName, equals('Screenshots'));
      expect(screenshotItem.computeTargetFolderPath(deviceFolder: 'Galaxy_S25'),
          equals('PhoneBackup/Galaxy_S25/Screenshots'));
    });
  });
}

