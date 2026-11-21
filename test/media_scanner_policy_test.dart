import 'package:flutter_test/flutter_test.dart';
import 'package:scanner/services/media_scanner_service.dart';

void main() {
  group('Media scanner privacy policy', () {
    test('recognizes private and locked paths', () {
      expect(
        MediaScannerService.isPrivateOrLockedPath(
          null,
          '/storage/ABCD/Pictures/.hidden/photo.jpg',
        ),
        isTrue,
      );
      expect(
        MediaScannerService.isPrivateOrLockedPath(
          'WhatsApp Private',
          '/storage/emulated/0/Android/media/photo.jpg',
        ),
        isTrue,
      );
      expect(
        MediaScannerService.isPrivateOrLockedPath(
          'Camera',
          '/storage/emulated/0/DCIM/Camera/photo.jpg',
        ),
        isFalse,
      );
    });

    test('does not classify unrelated names containing safe as locked', () {
      expect(
        MediaScannerService.isPrivateOrLockedPath(
          'SafeTravels',
          '/storage/emulated/0/Pictures/SafeTravels/photo.jpg',
        ),
        isFalse,
      );
    });
  });

  group('Media scanner sticker policy', () {
    test('excludes files and folders whose names identify stickers', () {
      expect(
        MediaScannerService.isStickerAsset(name: 'funny_sticker.webp'),
        isTrue,
      );
      expect(
        MediaScannerService.isStickerAsset(
          name: 'asset.webp',
          path:
              '/storage/emulated/0/WhatsApp/Media/WhatsApp Stickers/asset.webp',
        ),
        isTrue,
      );
    });

    test('excludes dedicated sticker formats', () {
      expect(MediaScannerService.isStickerAsset(name: 'animated.tgs'), isTrue);
      expect(
        MediaScannerService.isStickerAsset(name: 'pack.wastickers'),
        isTrue,
      );
    });

    test('keeps ordinary WebP media outside sticker locations', () {
      expect(
        MediaScannerService.isStickerAsset(
          name: 'photo.webp',
          path: '/storage/emulated/0/Pictures/photo.webp',
        ),
        isFalse,
      );
    });
  });
}
