import 'package:flutter_test/flutter_test.dart';
import 'package:scanner/models/media_item.dart';
import 'package:scanner/ui/screens/collage_maker_screen.dart';

MediaItem item(String id, AppMediaType type) => MediaItem(
  localId: id,
  fileName: '$id.${type == AppMediaType.video ? 'mp4' : 'jpg'}',
  mediaType: type,
  mimeType: type == AppMediaType.video ? 'video/mp4' : 'image/jpeg',
  fileSize: 1,
  createdAt: DateTime(2026),
);

void main() {
  test('collage accepts two or more photos', () {
    expect(
      CollageMakerScreen.canCreateFrom([
        item('one', AppMediaType.image),
        item('two', AppMediaType.image),
      ]),
      isTrue,
    );
  });

  test('collage rejects video and mixed selections', () {
    expect(
      CollageMakerScreen.canCreateFrom([
        item('one', AppMediaType.video),
        item('two', AppMediaType.video),
      ]),
      isFalse,
    );
    expect(
      CollageMakerScreen.canCreateFrom([
        item('one', AppMediaType.image),
        item('two', AppMediaType.video),
      ]),
      isFalse,
    );
  });
}
