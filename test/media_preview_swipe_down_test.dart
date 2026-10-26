import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanner/models/media_item.dart';
import 'package:scanner/ui/screens/media_preview_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testItem = MediaItem(
    localId: 'test_1',
    fileName: 'test_photo.jpg',
    mediaType: AppMediaType.image,
    mimeType: 'image/jpeg',
    fileSize: 1024 * 1024,
    createdAt: DateTime(2026, 10, 26, 10, 0),
  );

  testWidgets('Swiping down in MediaPreviewScreen pops and closes the screen', (tester) async {
    bool didPop = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                PageRouteBuilder(
                  opaque: false,
                  reverseTransitionDuration: Duration.zero,
                  pageBuilder: (_, _, _) => MediaPreviewScreen.single(item: testItem),
                ),
              ).then((_) {
                didPop = true;
              });
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    // Open media preview
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MediaPreviewScreen), findsOneWidget);
    expect(didPop, isFalse);

    // Perform swipe down gesture (from center down by 250 pixels)
    final center = tester.getCenter(find.byType(MediaPreviewScreen));
    await tester.dragFrom(center, const Offset(0, 250));
    // Step 1: Forward the dismiss animation (220ms)
    await tester.pump(const Duration(milliseconds: 250));
    // Step 2: Flush microtask which calls Navigator.of(context).pop()
    await tester.pump();
    // Step 3: Complete route pop exit transition (300ms)
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // Verify that the screen popped
    expect(didPop, isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(MediaPreviewScreen), findsNothing);
  });
}
