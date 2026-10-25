import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanner/ui/widgets/cached_thumbnail_image.dart';

void main() {
  testWidgets('CachedThumbnailImage renders placeholder when bytes are loading',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CachedThumbnailImage(
            localId: 'non_existent_asset_id',
            size: 320,
            placeholder: Text('Loading Placeholder'),
          ),
        ),
      ),
    );

    expect(find.text('Loading Placeholder'), findsOneWidget);
  });
}
