import 'package:flutter_test/flutter_test.dart';
import 'package:scanner/models/media_item.dart';
import 'package:scanner/services/vault_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('VaultService & Private Folder Tests', () {
    test('PIN setup, verification, and changing', () async {
      final vault = VaultService.instance;
      await vault.resetVaultPin();

      // Initially no PIN
      expect(await vault.isPinSet(), isFalse);
      expect(vault.isUnlocked, isFalse);

      // Set PIN
      final setResult = await vault.setPin('1234');
      expect(setResult, isTrue);
      expect(await vault.isPinSet(), isTrue);
      expect(vault.isUnlocked, isTrue);

      // Lock
      vault.lock();
      expect(vault.isUnlocked, isFalse);

      // Verify wrong PIN
      final wrong = await vault.verifyPin('0000');
      expect(wrong, isFalse);
      expect(vault.isUnlocked, isFalse);

      // Verify correct PIN
      final correct = await vault.verifyPin('1234');
      expect(correct, isTrue);
      expect(vault.isUnlocked, isTrue);

      // Change PIN
      final changeWrong = await vault.changePin('9999', '5678');
      expect(changeWrong, isFalse);

      final changeOk = await vault.changePin('1234', '5678');
      expect(changeOk, isTrue);

      vault.lock();
      expect(await vault.verifyPin('1234'), isFalse);
      expect(await vault.verifyPin('5678'), isTrue);
    });

    test('Moving item to Private Folder marks it locked and sets private sync path', () {
      final item = MediaItem(
        localId: 'test_photo_1',
        fileName: 'family_photo.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 1048576,
        createdAt: DateTime(2026, 6, 15),
        folderName: 'Camera',
      );

      expect(item.isLockedFolder, isFalse);
      expect(item.displayFolderName, equals('Camera'));
      expect(item.computeTargetFolderPath(deviceFolder: 'Pixel_8'),
          equals('PhoneBackup/Pixel_8/Camera'));

      // Move into private folder
      final lockedItem = item.copyWith(folderName: '.private');
      expect(lockedItem.isLockedFolder, isTrue);
      expect(lockedItem.displayFolderName, equals('Private (Locked)'));
      expect(lockedItem.computeTargetFolderPath(deviceFolder: 'Pixel_8'),
          equals('PhoneBackup/Pixel_8/Private (Locked)'));

      // Move out of private folder to another album
      final restoredItem = lockedItem.copyWith(folderName: 'Family');
      expect(restoredItem.isLockedFolder, isFalse);
      expect(restoredItem.displayFolderName, equals('Family'));
      expect(restoredItem.computeTargetFolderPath(deviceFolder: 'Pixel_8'),
          equals('PhoneBackup/Pixel_8/Family'));
    });

    test('Private folder items formatting and visibility', () {
      final lockedItem = MediaItem(
        localId: 'vault_1',
        fileName: 'private_doc.pdf',
        mediaType: AppMediaType.other,
        mimeType: 'application/pdf',
        fileSize: 500000,
        createdAt: DateTime(2026, 1, 1),
        folderName: '.private',
      );
      expect(lockedItem.isLockedFolder, isTrue);
      expect(lockedItem.displayFolderName, equals('Private (Locked)'));
    });

    test('Lock folder strictly isolates in-app locked items from other device folders', () async {
      final vault = VaultService.instance;
      await vault.init();

      // External file from device that happened to have .hidden or private in its path
      final externalItem = MediaItem(
        localId: 'ext_disk_99',
        fileName: 'other_app_secret.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 1000,
        createdAt: DateTime.now(),
        localFilePath: '/storage/emulated/0/WhatsApp/.private/other_app_secret.jpg',
        folderName: '.private',
      );

      // Verify that external device items are NOT considered in-app locked
      expect(vault.isLockedInApp(externalItem.localId), isFalse);

      // Item explicitly locked in this app
      final inAppItem = MediaItem(
        localId: 'user_photo_42',
        fileName: 'my_locked_photo.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 2000,
        createdAt: DateTime.now(),
        folderName: 'Camera',
      );

      // Lock item in this app
      await vault.moveToVault([inAppItem]);
      expect(vault.isLockedInApp('user_photo_42'), isTrue);
      expect(vault.isLockedInApp('ext_disk_99'), isFalse);

      // Move out of vault in this app
      await vault.moveOutOfVault([inAppItem], 'Camera');
      expect(vault.isLockedInApp('user_photo_42'), isFalse);
    });

    test('Moving out of private folder restores item to its original folder and location', () async {
      final vault = VaultService.instance;
      await vault.init();

      final screenshotItem = MediaItem(
        localId: 'screenshot_99',
        fileName: 'screenshot_receipt.png',
        mediaType: AppMediaType.image,
        mimeType: 'image/png',
        fileSize: 1500,
        createdAt: DateTime.now(),
        localFilePath: '/storage/emulated/0/Pictures/Screenshots/screenshot_receipt.png',
        folderName: 'Screenshots',
      );

      // Lock item from Screenshots
      await vault.moveToVault([screenshotItem]);
      expect(vault.isLockedInApp('screenshot_99'), isTrue);
      expect(vault.getOriginalFolder('screenshot_99'), equals('Screenshots'));

      // Move out without specifying destination folder -> restores to original location!
      await vault.moveOutOfVault([screenshotItem]);
      expect(vault.isLockedInApp('screenshot_99'), isFalse);
      expect(vault.getOriginalFolder('screenshot_99'), isNull);

      // Verify it is completely removed from private items without leaving ghost / corrupted items
      final privateItems = await vault.getPrivateItems();
      expect(privateItems.any((it) => it.localId == 'screenshot_99'), isFalse);
      expect(privateItems.any((it) => it.fileName == 'screenshot_receipt.png'), isFalse);
    });

    test('Vault files and manifest survive and recover after app data wipe simulation', () async {
      final vault = VaultService.instance;
      await vault.init();

      final item = MediaItem(
        localId: 'persistent_vault_1',
        fileName: 'confidential_contract.jpg',
        mediaType: AppMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 4000,
        createdAt: DateTime.now(),
        folderName: 'Documents',
      );

      await vault.moveToVault([item]);
      expect(vault.isLockedInApp('persistent_vault_1'), isTrue);

      // Simulate App Info -> Clear Data by clearing SharedPreferences
      SharedPreferences.setMockInitialValues({});

      // Querying private items self-heals and recovers from persistent manifest
      final items = await vault.getPrivateItems();
      expect(items.any((it) => it.fileName == 'confidential_contract.jpg'), isTrue);
    });
  });
}

