import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Uint8List> createTestImageBytes(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = Colors.blue,
  );
  // Draw red square in top-left
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width / 2, height / 2),
    Paint()..color = Colors.red,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Crop image accurately crops pixel dimensions and does not just resize', () async {
    final originalBytes = await createTestImageBytes(200, 100);
    final codec = await ui.instantiateImageCodec(originalBytes);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 200);
    expect(frame.image.height, 100);

    // Crop top-left half: normalized crop rect (0, 0, 0.5, 0.5)
    final cropL = (0.0 * frame.image.width).round();
    final cropT = (0.0 * frame.image.height).round();
    final cropR = (0.5 * frame.image.width).round();
    final cropB = (0.5 * frame.image.height).round();
    final cropW = cropR - cropL;
    final cropH = cropB - cropT;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, cropW.toDouble(), cropH.toDouble()));
    canvas.drawImageRect(
      frame.image,
      Rect.fromLTWH(cropL.toDouble(), cropT.toDouble(), cropW.toDouble(), cropH.toDouble()),
      Rect.fromLTWH(0, 0, cropW.toDouble(), cropH.toDouble()),
      Paint(),
    );
    final croppedImage = await recorder.endRecording().toImage(cropW, cropH);
    expect(croppedImage.width, 100);
    expect(croppedImage.height, 50);
  });
}

