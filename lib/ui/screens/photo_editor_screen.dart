import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../services/media_editor_service.dart';
import '../../services/media_scanner_service.dart';

enum PhotoEditorTab {
  crop,
  adjust,
  filter,
  draw,
  text,
}

enum FilterPreset {
  normal('Normal'),
  vivid('Vivid'),
  mono('B&W'),
  sepia('Sepia'),
  warm('Warm'),
  cool('Cool'),
  vintage('Vintage'),
  cyber('Cyber');

  final String label;
  const FilterPreset(this.label);
}

class DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  DrawingStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });
}

class PhotoEditorScreen extends StatefulWidget {
  final MediaItem item;

  const PhotoEditorScreen({super.key, required this.item});

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

enum _CropDragMode { none, move, topLeft, topRight, bottomLeft, bottomRight }

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  Uint8List? _imageBytes;
  Uint8List? _originalImageBytes;
  int _imagePixelWidth = 1;
  int _imagePixelHeight = 1;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isCropping = false;

  // Active Tab
  PhotoEditorTab _activeTab = PhotoEditorTab.adjust;

  // Transform / Crop state
  double? _selectedAspectRatio; // null = free/original
  Rect _cropRect = const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0);
  _CropDragMode _activeDragMode = _CropDragMode.none;
  Offset? _lastPanPos;

  // Adjustments (-1.0 to 1.0 or 0.0 to 2.0)
  double _brightness = 0.0; // -1.0 to 1.0
  double _contrast = 1.0; // 0.0 to 2.0
  double _saturation = 1.0; // 0.0 to 2.0
  double _warmth = 0.0; // -1.0 to 1.0

  // Filter Preset
  FilterPreset _selectedFilter = FilterPreset.normal;

  // Drawing state
  final List<DrawingStroke> _strokes = [];
  Color _drawColor = const Color(0xFF477BFF);
  final double _drawStrokeWidth = 4.0;
  List<Offset>? _currentPoints;

  // Text Overlay state
  String? _overlayText;
  Offset _textOffset = const Offset(60, 60);
  Color _textColor = Colors.white;
  double _textSize = 24.0;
  final TextEditingController _textEditingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      Uint8List? bytes;
      final file = await MediaScannerService.instance.getMediaFile(widget.item.localId);
      if (file != null && await file.exists()) {
        bytes = await file.readAsBytes();
      }

      if (bytes == null) {
        final asset = await AssetEntity.fromId(widget.item.localId);
        if (asset != null) {
          bytes = await asset.originBytes;
        }
      }

      if (bytes != null && mounted) {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        if (mounted) {
          setState(() {
            _originalImageBytes = bytes;
            _imageBytes = bytes;
            _imagePixelWidth = frame.image.width;
            _imagePixelHeight = frame.image.height;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetAdjustments() {
    setState(() {
      _imageBytes = _originalImageBytes;
      _cropRect = const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0);
      _selectedAspectRatio = null;
      _brightness = 0.0;
      _contrast = 1.0;
      _saturation = 1.0;
      _warmth = 0.0;
      _selectedFilter = FilterPreset.normal;
      _strokes.clear();
      _overlayText = null;
    });

    if (_originalImageBytes != null) {
      ui.instantiateImageCodec(_originalImageBytes!).then((codec) {
        codec.getNextFrame().then((frame) {
          if (mounted) {
            setState(() {
              _imagePixelWidth = frame.image.width;
              _imagePixelHeight = frame.image.height;
            });
          }
        });
      });
    }
  }

  /// High-performance GPU-accelerated image cropping using dart:ui
  Future<Uint8List> _cropImageBytes({
    required Uint8List bytes,
    required Rect normalizedCropRect,
    int quarterTurns = 0,
    bool flipHorizontal = false,
  }) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final imgW = image.width;
    final imgH = image.height;

    final cropL = (normalizedCropRect.left * imgW).round().clamp(0, imgW - 1);
    final cropT = (normalizedCropRect.top * imgH).round().clamp(0, imgH - 1);
    final cropR = (normalizedCropRect.right * imgW).round().clamp(cropL + 1, imgW);
    final cropB = (normalizedCropRect.bottom * imgH).round().clamp(cropT + 1, imgH);

    final cropW = cropR - cropL;
    final cropH = cropB - cropT;

    final isRotated90or270 = quarterTurns % 2 == 1;
    final rawTargetW = isRotated90or270 ? cropH : cropW;
    final rawTargetH = isRotated90or270 ? cropW : cropH;

    // Cap at 4096px to avoid device GPU texture limits on ultra-high resolution photos
    final maxDim = math.max(rawTargetW, rawTargetH);
    final scale = maxDim > 4096 ? 4096.0 / maxDim : 1.0;
    final targetW = (rawTargetW * scale).round().clamp(1, 4096);
    final targetH = (rawTargetH * scale).round().clamp(1, 4096);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
    );

    canvas.save();
    canvas.translate(targetW / 2.0, targetH / 2.0);
    if (quarterTurns != 0) {
      canvas.rotate(quarterTurns * math.pi / 2);
    }
    if (flipHorizontal) {
      canvas.scale(-1.0, 1.0);
    }

    final drawW = (isRotated90or270 ? targetH : targetW).toDouble();
    final drawH = (isRotated90or270 ? targetW : targetH).toDouble();

    final srcRect = Rect.fromLTWH(
      cropL.toDouble(),
      cropT.toDouble(),
      cropW.toDouble(),
      cropH.toDouble(),
    );
    final dstRect = Rect.fromLTWH(
      -drawW / 2.0,
      -drawH / 2.0,
      drawW,
      drawH,
    );

    canvas.drawImageRect(
      image,
      srcRect,
      dstRect,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();

    final picture = recorder.endRecording();
    final croppedUiImage = await picture.toImage(targetW, targetH);
    final byteData = await croppedUiImage.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    croppedUiImage.dispose();
    if (byteData == null) {
      throw Exception('Failed to encode cropped image to PNG');
    }
    return byteData.buffer.asUint8List();
  }

  Future<void> _applyCrop() async {
    if (_imageBytes == null) return;
    final isFullCrop = (_cropRect.left.abs() < 0.005 &&
        _cropRect.top.abs() < 0.005 &&
        (_cropRect.right - 1.0).abs() < 0.005 &&
        (_cropRect.bottom - 1.0).abs() < 0.005);

    if (isFullCrop) return;

    setState(() => _isCropping = true);
    try {
      final croppedBytes = await _cropImageBytes(
        bytes: _imageBytes!,
        normalizedCropRect: _cropRect,
        quarterTurns: 0,
        flipHorizontal: false,
      );

      final codec = await ui.instantiateImageCodec(croppedBytes);
      final frame = await codec.getNextFrame();

      if (mounted) {
        setState(() {
          _imageBytes = croppedBytes;
          _imagePixelWidth = frame.image.width;
          _imagePixelHeight = frame.image.height;
          _cropRect = const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0);
          _selectedAspectRatio = null;
          _isCropping = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Crop applied successfully!'),
            backgroundColor: AppTheme.colors(context).accentGreen,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to crop: $e'),
            backgroundColor: AppTheme.colors(context).accentRose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _rotate90Degrees() async {
    if (_imageBytes == null) return;
    setState(() => _isCropping = true);
    try {
      final rotated = await _cropImageBytes(
        bytes: _imageBytes!,
        normalizedCropRect: const Rect.fromLTWH(0, 0, 1, 1),
        quarterTurns: 1,
        flipHorizontal: false,
      );
      final codec = await ui.instantiateImageCodec(rotated);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _imageBytes = rotated;
          _imagePixelWidth = frame.image.width;
          _imagePixelHeight = frame.image.height;
          _cropRect = const Rect.fromLTWH(0, 0, 1, 1);
          _selectedAspectRatio = null;
          _isCropping = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCropping = false);
    }
  }

  Future<void> _flipHorizontally() async {
    if (_imageBytes == null) return;
    setState(() => _isCropping = true);
    try {
      final flipped = await _cropImageBytes(
        bytes: _imageBytes!,
        normalizedCropRect: const Rect.fromLTWH(0, 0, 1, 1),
        quarterTurns: 0,
        flipHorizontal: true,
      );
      if (mounted) {
        setState(() {
          _imageBytes = flipped;
          _cropRect = const Rect.fromLTWH(0, 0, 1, 1);
          _isCropping = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCropping = false);
    }
  }

  void _setAspectRatio(double? ratio) {
    setState(() {
      _selectedAspectRatio = ratio;
      if (ratio == null) return;
      if (_imagePixelWidth <= 0 || _imagePixelHeight <= 0) return;

      final K = ratio * (_imagePixelHeight / _imagePixelWidth);

      double w, h;
      if (K <= 1.0) {
        h = 1.0;
        w = K;
      } else {
        w = 1.0;
        h = 1.0 / K;
      }
      final left = ((1.0 - w) / 2.0).clamp(0.0, 1.0);
      final top = ((1.0 - h) / 2.0).clamp(0.0, 1.0);
      _cropRect = Rect.fromLTWH(left, top, w, h);
    });
  }

  void _handleCropPanStart(DragStartDetails details, Size imageSize) {
    final pos = details.localPosition;
    final screenCrop = Rect.fromLTRB(
      _cropRect.left * imageSize.width,
      _cropRect.top * imageSize.height,
      _cropRect.right * imageSize.width,
      _cropRect.bottom * imageSize.height,
    );

    const r = 44.0;
    if ((pos - screenCrop.topLeft).distance <= r) {
      _activeDragMode = _CropDragMode.topLeft;
    } else if ((pos - screenCrop.topRight).distance <= r) {
      _activeDragMode = _CropDragMode.topRight;
    } else if ((pos - screenCrop.bottomLeft).distance <= r) {
      _activeDragMode = _CropDragMode.bottomLeft;
    } else if ((pos - screenCrop.bottomRight).distance <= r) {
      _activeDragMode = _CropDragMode.bottomRight;
    } else if (screenCrop.contains(pos)) {
      _activeDragMode = _CropDragMode.move;
    } else {
      _activeDragMode = _CropDragMode.none;
    }
    _lastPanPos = pos;
  }

  void _handleCropPanUpdate(DragUpdateDetails details, Size imageSize) {
    if (_activeDragMode == _CropDragMode.none || _lastPanPos == null) return;
    if (imageSize.width <= 0 || imageSize.height <= 0) return;

    final delta = details.localPosition - _lastPanPos!;
    _lastPanPos = details.localPosition;

    final dNormX = delta.dx / imageSize.width;
    final dNormY = delta.dy / imageSize.height;

    final K = _selectedAspectRatio != null
        ? _selectedAspectRatio! * (_imagePixelHeight / _imagePixelWidth)
        : null;

    setState(() {
      if (_activeDragMode == _CropDragMode.move) {
        double dx = dNormX;
        double dy = dNormY;
        if (_cropRect.left + dx < 0) dx = -_cropRect.left;
        if (_cropRect.right + dx > 1.0) dx = 1.0 - _cropRect.right;
        if (_cropRect.top + dy < 0) dy = -_cropRect.top;
        if (_cropRect.bottom + dy > 1.0) dy = 1.0 - _cropRect.bottom;
        _cropRect = _cropRect.shift(Offset(dx, dy));
      } else if (K != null) {
        if (_activeDragMode == _CropDragMode.bottomRight) {
          double newW = (_cropRect.width + dNormX).clamp(0.15, 1.0 - _cropRect.left);
          double newH = newW / K;
          if (_cropRect.top + newH > 1.0) {
            newH = 1.0 - _cropRect.top;
            newW = newH * K;
          }
          if (newW >= 0.15 && newH >= 0.15) {
            _cropRect = Rect.fromLTWH(_cropRect.left, _cropRect.top, newW, newH);
          }
        } else if (_activeDragMode == _CropDragMode.bottomLeft) {
          double newW = (_cropRect.width - dNormX).clamp(0.15, _cropRect.right);
          double newH = newW / K;
          if (_cropRect.top + newH > 1.0) {
            newH = 1.0 - _cropRect.top;
            newW = newH * K;
          }
          if (newW >= 0.15 && newH >= 0.15) {
            _cropRect = Rect.fromLTRB(_cropRect.right - newW, _cropRect.top, _cropRect.right, _cropRect.top + newH);
          }
        } else if (_activeDragMode == _CropDragMode.topRight) {
          double newW = (_cropRect.width + dNormX).clamp(0.15, 1.0 - _cropRect.left);
          double newH = newW / K;
          if (_cropRect.bottom - newH < 0.0) {
            newH = _cropRect.bottom;
            newW = newH * K;
          }
          if (newW >= 0.15 && newH >= 0.15) {
            _cropRect = Rect.fromLTRB(_cropRect.left, _cropRect.bottom - newH, _cropRect.left + newW, _cropRect.bottom);
          }
        } else if (_activeDragMode == _CropDragMode.topLeft) {
          double newW = (_cropRect.width - dNormX).clamp(0.15, _cropRect.right);
          double newH = newW / K;
          if (_cropRect.bottom - newH < 0.0) {
            newH = _cropRect.bottom;
            newW = newH * K;
          }
          if (newW >= 0.15 && newH >= 0.15) {
            _cropRect = Rect.fromLTRB(_cropRect.right - newW, _cropRect.bottom - newH, _cropRect.right, _cropRect.bottom);
          }
        }
      } else {
        if (_activeDragMode == _CropDragMode.topLeft) {
          final l = (_cropRect.left + dNormX).clamp(0.0, _cropRect.right - 0.15);
          final t = (_cropRect.top + dNormY).clamp(0.0, _cropRect.bottom - 0.15);
          _cropRect = Rect.fromLTRB(l, t, _cropRect.right, _cropRect.bottom);
        } else if (_activeDragMode == _CropDragMode.topRight) {
          final r = (_cropRect.right + dNormX).clamp(_cropRect.left + 0.15, 1.0);
          final t = (_cropRect.top + dNormY).clamp(0.0, _cropRect.bottom - 0.15);
          _cropRect = Rect.fromLTRB(_cropRect.left, t, r, _cropRect.bottom);
        } else if (_activeDragMode == _CropDragMode.bottomLeft) {
          final l = (_cropRect.left + dNormX).clamp(0.0, _cropRect.right - 0.15);
          final b = (_cropRect.bottom + dNormY).clamp(_cropRect.top + 0.15, 1.0);
          _cropRect = Rect.fromLTRB(l, _cropRect.top, _cropRect.right, b);
        } else if (_activeDragMode == _CropDragMode.bottomRight) {
          final r = (_cropRect.right + dNormX).clamp(_cropRect.left + 0.15, 1.0);
          final b = (_cropRect.bottom + dNormY).clamp(_cropRect.top + 0.15, 1.0);
          _cropRect = Rect.fromLTRB(_cropRect.left, _cropRect.top, r, b);
        }
      }
    });
  }

  void _handleCropPanEnd(DragEndDetails details) {
    _activeDragMode = _CropDragMode.none;
    _lastPanPos = null;
  }

  List<double> _calculateColorMatrix() {
    // 1. Base identity matrix
    List<double> m = [
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ];

    // 2. Preset Filter application
    switch (_selectedFilter) {
      case FilterPreset.vivid:
        m = [
          1.3, 0, 0, 0, 5,
          0, 1.3, 0, 0, 5,
          0, 0, 1.3, 0, 5,
          0, 0, 0, 1, 0,
        ];
        break;
      case FilterPreset.mono:
        m = [
          0.299, 0.587, 0.114, 0, 0,
          0.299, 0.587, 0.114, 0, 0,
          0.299, 0.587, 0.114, 0, 0,
          0, 0, 0, 1, 0,
        ];
        break;
      case FilterPreset.sepia:
        m = [
          0.393, 0.769, 0.189, 0, 0,
          0.349, 0.686, 0.168, 0, 0,
          0.272, 0.534, 0.131, 0, 0,
          0, 0, 0, 1, 0,
        ];
        break;
      case FilterPreset.warm:
        m = [
          1.15, 0, 0, 0, 15,
          0, 1.05, 0, 0, 5,
          0, 0, 0.85, 0, -10,
          0, 0, 0, 1, 0,
        ];
        break;
      case FilterPreset.cool:
        m = [
          0.85, 0, 0, 0, -10,
          0, 1.0, 0, 0, 5,
          0, 0, 1.2, 0, 20,
          0, 0, 0, 1, 0,
        ];
        break;
      case FilterPreset.vintage:
        m = [
          0.9, 0.1, 0.1, 0, 10,
          0.05, 0.85, 0.1, 0, 10,
          0.05, 0.1, 0.75, 0, 20,
          0, 0, 0, 1, 0,
        ];
        break;
      case FilterPreset.cyber:
        m = [
          1.2, 0, 0.3, 0, 20,
          0, 1.0, 0, 0, -10,
          0.2, 0, 1.4, 0, 30,
          0, 0, 0, 1, 0,
        ];
        break;
      case FilterPreset.normal:
        break;
    }

    // 3. Brightness (-1 to 1 => -255 to 255 offset)
    final bOffset = _brightness * 128;
    m[4] += bOffset;
    m[9] += bOffset;
    m[14] += bOffset;

    // 4. Contrast (scale factor with center 128)
    if (_contrast != 1.0) {
      final c = _contrast;
      final t = (1.0 - c) / 2.0 * 255;
      m[0] *= c;
      m[6] *= c;
      m[12] *= c;
      m[4] += t;
      m[9] += t;
      m[14] += t;
    }

    // 5. Saturation
    if (_saturation != 1.0) {
      final s = _saturation;
      final invS = 1.0 - s;
      final rL = 0.2126 * invS;
      final gL = 0.7152 * invS;
      final bL = 0.0722 * invS;

      m[0] = m[0] * (rL + s);
      m[1] = m[1] + gL;
      m[2] = m[2] + bL;

      m[5] = m[5] + rL;
      m[6] = m[6] * (gL + s);
      m[7] = m[7] + bL;

      m[10] = m[10] + rL;
      m[11] = m[11] + gL;
      m[12] = m[12] * (bL + s);
    }

    // 6. Warmth
    if (_warmth != 0.0) {
      m[4] += _warmth * 40; // Red boost
      m[14] -= _warmth * 30; // Blue attenuate
    }

    return m;
  }

  Future<void> _saveEditedImage() async {
    if (_isSaving) return;

    final isFullCrop = (_cropRect.left.abs() < 0.005 &&
        _cropRect.top.abs() < 0.005 &&
        (_cropRect.right - 1.0).abs() < 0.005 &&
        (_cropRect.bottom - 1.0).abs() < 0.005);
    if (!isFullCrop) {
      await _applyCrop();
    }

    setState(() => _isSaving = true);

    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Canvas not ready');
      }

      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to export bytes');
      }

      final pngBytes = byteData.buffer.asUint8List();

      final savedItem = await MediaEditorService.instance.saveEditedImage(
        bytes: pngBytes,
        originalFileName: widget.item.fileName,
        originalLocalId: widget.item.localId,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        if (savedItem != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Edited image saved to gallery!'),
              backgroundColor: AppTheme.colors(context).accentGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop(savedItem);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to save edited image.'),
              backgroundColor: AppTheme.colors(context).accentRose,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.colors(context).accentRose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAddTextDialog() {
    _textEditingController.text = _overlayText ?? '';
    showDialog(
      context: context,
      builder: (ctx) {
        final c = AppTheme.colors(context);
        return AlertDialog(
          backgroundColor: c.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Add Text', style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _textEditingController,
                autofocus: true,
                style: TextStyle(color: c.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Enter text here...',
                  hintStyle: TextStyle(color: c.textTertiary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Colors.white,
                    Colors.black,
                    const Color(0xFF477BFF),
                    const Color(0xFF55D6A0),
                    const Color(0xFFFF747E),
                    const Color(0xFFF0B969),
                    const Color(0xFF8067FF),
                  ].map((color) {
                    final isSel = _textColor == color;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _textColor = color);
                        Navigator.of(ctx).pop();
                        _showAddTextDialog();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSel
                              ? Border.all(color: Colors.white, width: 3)
                              : Border.all(color: Colors.white38, width: 1),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _overlayText = null);
                Navigator.of(ctx).pop();
              },
              child: Text('Delete', style: TextStyle(color: c.accentRose)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                setState(() {
                  _overlayText = _textEditingController.text.trim().isEmpty
                      ? null
                      : _textEditingController.text.trim();
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('Apply', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);

    const systemOverlay = SystemUiOverlayStyle(
      statusBarColor: Color(0xFF000000),
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF000000),
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Color(0xFF000000),
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    );

    if (_isLoading) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: systemOverlay,
        child: Scaffold(
          backgroundColor: c.bg,
          body: Center(
            child: CircularProgressIndicator(color: c.primary),
          ),
        ),
      );
    }

    if (_imageBytes == null) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: systemOverlay,
        child: Scaffold(
          backgroundColor: c.bg,
          appBar: AppBar(backgroundColor: c.bg, elevation: 0),
          body: Center(
            child: Text('Failed to load image', style: TextStyle(color: c.textSecondary)),
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlay,
      child: Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildTopBar(c),

            // Canvas Workspace
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildImageCanvas(c),
                ),
              ),
            ),

            // Tool Adjuster Bar (Sub-controls)
            _buildSubControls(c),

            // Main Editor Tab Navigation
            _buildBottomTabBar(c),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildTopBar(AppThemeColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        border: Border(bottom: BorderSide(color: c.glassBorderSubtle, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minSize: 0,
            onPressed: _resetAdjustments,
            child: Text(
              'Reset',
              style: TextStyle(color: c.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: _isSaving ? null : _saveEditedImage,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: AppTheme.appleYellow, strokeWidth: 2),
                  )
                : const Text(
                    'Done',
                    style: TextStyle(
                      color: AppTheme.appleYellow,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCanvas(AppThemeColors c) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double imgAspect = (_imagePixelWidth > 0 && _imagePixelHeight > 0)
            ? _imagePixelWidth / _imagePixelHeight
            : 1.0;
        final double containerAspect = constraints.maxWidth / constraints.maxHeight;

        double drawW, drawH;
        if (imgAspect > containerAspect) {
          drawW = constraints.maxWidth;
          drawH = drawW / imgAspect;
        } else {
          drawH = constraints.maxHeight;
          drawW = drawH * imgAspect;
        }

        final imageDisplaySize = Size(drawW, drawH);

        Widget imageWidget = Image.memory(
          _imageBytes!,
          fit: BoxFit.fill,
          width: drawW,
          height: drawH,
        );

        // Apply Real-time Color Filter Matrix
        imageWidget = ColorFiltered(
          colorFilter: ColorFilter.matrix(_calculateColorMatrix()),
          child: imageWidget,
        );

        return Center(
          child: SizedBox(
            width: drawW,
            height: drawH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Exact image bounding box wrapped in RepaintBoundary for high-res lossless capture
                RepaintBoundary(
                  key: _repaintBoundaryKey,
                  child: SizedBox(
                    width: drawW,
                    height: drawH,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(child: imageWidget),

                        // Drawing Canvas on top
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: _activeTab == PhotoEditorTab.draw
                                ? HitTestBehavior.opaque
                                : HitTestBehavior.translucent,
                            onPanStart: _activeTab == PhotoEditorTab.draw
                                ? (details) {
                                    setState(() {
                                      _currentPoints = [details.localPosition];
                                      _strokes.add(
                                        DrawingStroke(
                                          points: _currentPoints!,
                                          color: _drawColor,
                                          strokeWidth: _drawStrokeWidth,
                                        ),
                                      );
                                    });
                                  }
                                : null,
                            onPanUpdate: _activeTab == PhotoEditorTab.draw
                                ? (details) {
                                    setState(() {
                                      _currentPoints?.add(details.localPosition);
                                    });
                                  }
                                : null,
                            onPanEnd: _activeTab == PhotoEditorTab.draw
                                ? (_) {
                                    _currentPoints = null;
                                  }
                                : null,
                            child: CustomPaint(
                              painter: _DrawingPainter(strokes: _strokes),
                            ),
                          ),
                        ),

                        // Draggable Text Overlay
                        if (_overlayText != null)
                          Positioned(
                            left: _textOffset.dx,
                            top: _textOffset.dy,
                            child: GestureDetector(
                              onPanUpdate: (details) {
                                setState(() {
                                  _textOffset += details.delta;
                                });
                              },
                              onTap: _showAddTextDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white30, width: 0.5),
                                ),
                                child: Text(
                                  _overlayText!,
                                  style: TextStyle(
                                    color: _textColor,
                                    fontSize: _textSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Interactive Crop Frame & Overlay (Strictly confined to photo boundaries)
                if (_activeTab == PhotoEditorTab.crop)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) => _handleCropPanStart(details, imageDisplaySize),
                      onPanUpdate: (details) => _handleCropPanUpdate(details, imageDisplaySize),
                      onPanEnd: _handleCropPanEnd,
                      child: CustomPaint(
                        size: imageDisplaySize,
                        painter: _CropOverlayPainter(
                          normalizedCropRect: _cropRect,
                          borderColor: Colors.white,
                          showGrid: true,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubControls(AppThemeColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: c.surfaceElevated.withOpacity(0.85),
        border: Border(top: BorderSide(color: c.glassBorderSubtle, width: 0.5)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _buildSubControlContent(c),
      ),
    );
  }

  Widget _buildSubControlContent(AppThemeColors c) {
    switch (_activeTab) {
      case PhotoEditorTab.crop:
        final origAspect = _imagePixelWidth > 0 && _imagePixelHeight > 0
            ? _imagePixelWidth / _imagePixelHeight
            : null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Aspect Ratio Presets
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildAspectButton('Free', null, c),
                  if (origAspect != null)
                    _buildAspectButton('Original', origAspect, c),
                  _buildAspectButton('1:1', 1.0, c),
                  _buildAspectButton('4:5', 4 / 5, c),
                  _buildAspectButton('16:9', 16 / 9, c),
                  _buildAspectButton('9:16', 9 / 16, c),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Row 2: Transform Tools & Apply Crop Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.rotate_90_degrees_cw_outlined, color: c.primary),
                      tooltip: 'Rotate 90°',
                      onPressed: _rotate90Degrees,
                    ),
                    IconButton(
                      icon: Icon(Icons.flip_outlined, color: c.primary),
                      tooltip: 'Flip Horizontal',
                      onPressed: _flipHorizontally,
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh_outlined, color: c.textSecondary),
                      tooltip: 'Reset Crop Frame',
                      onPressed: () {
                        setState(() {
                          _cropRect = const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0);
                          _selectedAspectRatio = null;
                        });
                      },
                    ),
                  ],
                ),

                // Prominent "Apply Crop" Action Button
                ElevatedButton.icon(
                  onPressed: _isCropping ? null : _applyCrop,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  icon: _isCropping
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.crop_outlined, size: 15),
                  label: const Text(
                    'Apply Crop',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        );

      case PhotoEditorTab.adjust:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSliderRow(
              icon: Icons.brightness_6_outlined,
              label: 'Brightness',
              value: _brightness,
              min: -1.0,
              max: 1.0,
              onChanged: (val) => setState(() => _brightness = val),
              c: c,
            ),
            _buildSliderRow(
              icon: Icons.contrast_outlined,
              label: 'Contrast',
              value: _contrast,
              min: 0.2,
              max: 2.0,
              onChanged: (val) => setState(() => _contrast = val),
              c: c,
            ),
            _buildSliderRow(
              icon: Icons.color_lens_outlined,
              label: 'Saturation',
              value: _saturation,
              min: 0.0,
              max: 2.0,
              onChanged: (val) => setState(() => _saturation = val),
              c: c,
            ),
            _buildSliderRow(
              icon: Icons.thermostat_outlined,
              label: 'Warmth',
              value: _warmth,
              min: -1.0,
              max: 1.0,
              onChanged: (val) => setState(() => _warmth = val),
              c: c,
            ),
          ],
        );

      case PhotoEditorTab.filter:
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: FilterPreset.values.map((preset) {
              final isSelected = _selectedFilter == preset;
              return GestureDetector(
                onTap: () => setState(() => _selectedFilter = preset),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? c.primary : c.surfaceGlassFloating,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? c.primaryLight : c.glassBorder,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    preset.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : c.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );

      case PhotoEditorTab.draw:
        return Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Color(0xFF477BFF),
                    const Color(0xFF55D6A0),
                    const Color(0xFFFF747E),
                    const Color(0xFFF0B969),
                    const Color(0xFF8067FF),
                    Colors.white,
                    Colors.black,
                  ].map((color) {
                    final isSel = _drawColor == color;
                    return GestureDetector(
                      onTap: () => setState(() => _drawColor = color),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSel
                              ? Border.all(color: Colors.white, width: 2.5)
                              : Border.all(color: Colors.white24, width: 1),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.undo_outlined, color: _strokes.isEmpty ? c.textTertiary : c.textPrimary),
              onPressed: _strokes.isEmpty
                  ? null
                  : () {
                      setState(() {
                        _strokes.removeLast();
                      });
                    },
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: _strokes.isEmpty ? c.textTertiary : c.accentRose),
              onPressed: _strokes.isEmpty
                  ? null
                  : () {
                      setState(() {
                        _strokes.clear();
                      });
                    },
            ),
          ],
        );

      case PhotoEditorTab.text:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _showAddTextDialog,
              icon: const Icon(Icons.text_fields_rounded, color: Colors.white, size: 18),
              label: Text(
                _overlayText == null ? 'Add Text' : 'Edit Text',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            if (_overlayText != null)
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.text_decrease_rounded, color: c.textPrimary),
                    onPressed: () {
                      setState(() {
                        _textSize = math.max(14.0, _textSize - 3);
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.text_increase_rounded, color: c.textPrimary),
                    onPressed: () {
                      setState(() {
                        _textSize = math.min(50.0, _textSize + 3);
                      });
                    },
                  ),
                ],
              ),
          ],
        );
    }
  }

  Widget _buildSliderRow({
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required AppThemeColors c,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: c.primary, size: 18),
          const SizedBox(width: 8),
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(color: c.textPrimary, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: c.primary,
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 2.5,
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAspectButton(String label, double? ratio, AppThemeColors c) {
    final isSelected = _selectedAspectRatio == ratio;
    return GestureDetector(
      onTap: () => _setAspectRatio(ratio),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? c.primary.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? c.primary : c.glassBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? c.primary : c.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomTabBar(AppThemeColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        border: Border(top: BorderSide(color: c.glassBorderSubtle, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTabItem(PhotoEditorTab.adjust, CupertinoIcons.slider_horizontal_3, 'Adjust', c),
          _buildTabItem(PhotoEditorTab.filter, CupertinoIcons.circle_grid_hex, 'Filters', c),
          _buildTabItem(PhotoEditorTab.crop, CupertinoIcons.crop_rotate, 'Crop', c),
          _buildTabItem(PhotoEditorTab.draw, CupertinoIcons.pencil, 'Markup', c),
          _buildTabItem(PhotoEditorTab.text, CupertinoIcons.textformat, 'Text', c),
        ],
      ),
    );
  }

  Widget _buildTabItem(PhotoEditorTab tab, IconData icon, String label, AppThemeColors c) {
    final isSelected = _activeTab == tab;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 0,
      onPressed: () => setState(() => _activeTab = tab),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? AppTheme.appleYellow : Colors.white54,
            size: 22,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.appleYellow : Colors.white54,
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;

  _DrawingPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.strokeWidth
        ..style = PaintingStyle.stroke;

      if (stroke.points.length < 2) {
        if (stroke.points.isNotEmpty) {
          canvas.drawCircle(stroke.points.first, stroke.strokeWidth / 2, paint..style = PaintingStyle.fill);
        }
        continue;
      }

      final path = Path();
      path.moveTo(stroke.points[0].dx, stroke.points[0].dy);

      for (int i = 1; i < stroke.points.length; i++) {
        final p0 = stroke.points[i - 1];
        final p1 = stroke.points[i];
        path.quadraticBezierTo(
          p0.dx,
          p0.dy,
          (p0.dx + p1.dx) / 2,
          (p0.dy + p1.dy) / 2,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}

class _CropOverlayPainter extends CustomPainter {
  final Rect normalizedCropRect;
  final Color borderColor;
  final bool showGrid;

  _CropOverlayPainter({
    required this.normalizedCropRect,
    required this.borderColor,
    this.showGrid = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final screenCropRect = Rect.fromLTRB(
      (normalizedCropRect.left * size.width).clamp(0.0, size.width),
      (normalizedCropRect.top * size.height).clamp(0.0, size.height),
      (normalizedCropRect.right * size.width).clamp(0.0, size.width),
      (normalizedCropRect.bottom * size.height).clamp(0.0, size.height),
    );

    // 1. Dark translucent backdrop outside crop region (confined to photo bounds)
    final maskPaint = Paint()..color = Colors.black.withOpacity(0.60);

    if (screenCropRect.top > 0) {
      canvas.drawRect(Rect.fromLTRB(0, 0, size.width, screenCropRect.top), maskPaint);
    }
    if (screenCropRect.bottom < size.height) {
      canvas.drawRect(Rect.fromLTRB(0, screenCropRect.bottom, size.width, size.height), maskPaint);
    }
    if (screenCropRect.left > 0) {
      canvas.drawRect(
        Rect.fromLTRB(0, screenCropRect.top, screenCropRect.left, screenCropRect.bottom),
        maskPaint,
      );
    }
    if (screenCropRect.right < size.width) {
      canvas.drawRect(
        Rect.fromLTRB(screenCropRect.right, screenCropRect.top, size.width, screenCropRect.bottom),
        maskPaint,
      );
    }

    // 2. Crop Frame Border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawRect(screenCropRect, borderPaint);

    // 3. Rule of Thirds Grid
    if (showGrid && screenCropRect.width > 24 && screenCropRect.height > 24) {
      final gridPaint = Paint()
        ..color = Colors.white.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;

      final thirdW = screenCropRect.width / 3.0;
      final thirdH = screenCropRect.height / 3.0;

      canvas.drawLine(
        Offset(screenCropRect.left + thirdW, screenCropRect.top),
        Offset(screenCropRect.left + thirdW, screenCropRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(screenCropRect.left + thirdW * 2, screenCropRect.top),
        Offset(screenCropRect.left + thirdW * 2, screenCropRect.bottom),
        gridPaint,
      );

      canvas.drawLine(
        Offset(screenCropRect.left, screenCropRect.top + thirdH),
        Offset(screenCropRect.right, screenCropRect.top + thirdH),
        gridPaint,
      );
      canvas.drawLine(
        Offset(screenCropRect.left, screenCropRect.top + thirdH * 2),
        Offset(screenCropRect.right, screenCropRect.top + thirdH * 2),
        gridPaint,
      );
    }

    // 4. Corner Handles (Thick L-shapes)
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.square;

    const cornerLen = 20.0;
    final cW = math.min(cornerLen, screenCropRect.width / 3);
    final cH = math.min(cornerLen, screenCropRect.height / 3);

    // Top-Left
    canvas.drawLine(screenCropRect.topLeft, screenCropRect.topLeft + Offset(cW, 0), cornerPaint);
    canvas.drawLine(screenCropRect.topLeft, screenCropRect.topLeft + Offset(0, cH), cornerPaint);

    // Top-Right
    canvas.drawLine(screenCropRect.topRight, screenCropRect.topRight + Offset(-cW, 0), cornerPaint);
    canvas.drawLine(screenCropRect.topRight, screenCropRect.topRight + Offset(0, cH), cornerPaint);

    // Bottom-Left
    canvas.drawLine(screenCropRect.bottomLeft, screenCropRect.bottomLeft + Offset(cW, 0), cornerPaint);
    canvas.drawLine(screenCropRect.bottomLeft, screenCropRect.bottomLeft + Offset(0, -cH), cornerPaint);

    // Bottom-Right
    canvas.drawLine(screenCropRect.bottomRight, screenCropRect.bottomRight + Offset(-cW, 0), cornerPaint);
    canvas.drawLine(screenCropRect.bottomRight, screenCropRect.bottomRight + Offset(0, -cH), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) =>
      oldDelegate.normalizedCropRect != normalizedCropRect ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.showGrid != showGrid;
}
