import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanner/ui/widgets/three_d_touch_card.dart';

void main() {
  testWidgets('ThreeDTouchCard renders child and triggers onTap', (tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 150,
              height: 150,
              child: ThreeDTouchCard(
                onTap: () => tapped = true,
                child: const Text('3D Card Content'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('3D Card Content'), findsOneWidget);

    await tester.tap(find.text('3D Card Content'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}
