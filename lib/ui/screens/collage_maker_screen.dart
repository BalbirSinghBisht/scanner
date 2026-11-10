import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../services/media_editor_service.dart';
import '../../services/media_scanner_service.dart';

enum CollageAspectRatio {
  square('1:1', 1.0),
  portrait('4:5', 4 / 5),
  story('9:16', 9 / 16),
  landscape('16:9', 16 / 9);

  final String label;
  final double ratio;
  const CollageAspectRatio(this.label, this.ratio);
}

class CollageMakerScreen extends StatefulWidget {
  final List<MediaItem> items;

  const CollageMakerScreen({
    super.key,
    required this.items,
  });

  @override
  State<CollageMakerScreen> createState() => _CollageMakerScreenState();
}

class _CollageMakerScreenState extends State<CollageMakerScreen> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  late List<MediaItem> _selectedItems;
  CollageAspectRatio _aspectRatio = CollageAspectRatio.square;
  double _spacing = 6.0;
  double _borderRadius = 10.0;
  Color _backgroundColor = Colors.black;
  int _layoutStyle = 0; // Layout variant index
  bool _isSaving = false;

  final Map<String, Uint8List> _loadedImages = {};
  bool _isLoadingImages = true;

  @override
  void initState() {
    super.initState();
    // Support up to 6 items
    _selectedItems = widget.items.take(6).toList();
    _loadAllImages();
  }

  Future<void> _loadAllImages() async {
    for (final item in _selectedItems) {
      try {
        final file = await MediaScannerService.instance.getMediaFile(item.localId);
        if (file != null && await file.exists()) {
          final bytes = await file.readAsBytes();
          _loadedImages[item.localId] = bytes;
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _isLoadingImages = false);
    }
  }

  Future<void> _saveCollage() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Collage canvas not ready');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to render collage');

      final pngBytes = byteData.buffer.asUint8List();

      final savedItem = await MediaEditorService.instance.saveEditedImage(
        bytes: pngBytes,
        originalFileName: 'collage_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (mounted) {
        setState(() => _isSaving = false);
        if (savedItem != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Collage saved directly to DCIM folder!'),
              backgroundColor: AppTheme.colors(context).accentGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop(savedItem);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to save collage.'),
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

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final systemUiOverlay = SystemUiOverlayStyle(
      statusBarColor:
          isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor:
          isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor:
          isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlay,
      child: Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(c),

            // Center Workspace
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _isLoadingImages
                      ? CircularProgressIndicator(color: c.primary)
                      : _buildCollageCanvas(),
                ),
              ),
            ),

            // Controls Panel
            _buildControlsPanel(c),
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
        color: c.isDark ? Colors.black.withOpacity(0.85) : Colors.white.withOpacity(0.95),
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
                color: AppTheme.appleBlue,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Text(
            'Collage (${_selectedItems.length})',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: _isSaving ? null : _saveCollage,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: AppTheme.appleBlue, strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: AppTheme.appleBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollageCanvas() {
    return AspectRatio(
      aspectRatio: _aspectRatio.ratio,
      child: RepaintBoundary(
        key: _repaintBoundaryKey,
        child: Container(
          color: _backgroundColor,
          padding: EdgeInsets.all(_spacing),
          child: _buildGridStructure(),
        ),
      ),
    );
  }

  Widget _buildGridStructure() {
    final n = _selectedItems.length;

    if (n == 2) {
      // 2 photos: Vertical Split or Horizontal Split
      if (_layoutStyle % 2 == 0) {
        return Row(
          children: [
            Expanded(child: _buildCell(0)),
            SizedBox(width: _spacing),
            Expanded(child: _buildCell(1)),
          ],
        );
      } else {
        return Column(
          children: [
            Expanded(child: _buildCell(0)),
            SizedBox(height: _spacing),
            Expanded(child: _buildCell(1)),
          ],
        );
      }
    } else if (n == 3) {
      // 3 photos: 1 Left + 2 Right or 3 Columns
      if (_layoutStyle % 2 == 0) {
        return Row(
          children: [
            Expanded(flex: 3, child: _buildCell(0)),
            SizedBox(width: _spacing),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Expanded(child: _buildCell(1)),
                  SizedBox(height: _spacing),
                  Expanded(child: _buildCell(2)),
                ],
              ),
            ),
          ],
        );
      } else {
        return Column(
          children: [
            Expanded(flex: 3, child: _buildCell(0)),
            SizedBox(height: _spacing),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Expanded(child: _buildCell(1)),
                  SizedBox(width: _spacing),
                  Expanded(child: _buildCell(2)),
                ],
              ),
            ),
          ],
        );
      }
    } else if (n == 4) {
      // 4 photos: 2x2 Grid or 1 Top + 3 Bottom
      if (_layoutStyle % 2 == 0) {
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildCell(0)),
                  SizedBox(width: _spacing),
                  Expanded(child: _buildCell(1)),
                ],
              ),
            ),
            SizedBox(height: _spacing),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildCell(2)),
                  SizedBox(width: _spacing),
                  Expanded(child: _buildCell(3)),
                ],
              ),
            ),
          ],
        );
      } else {
        return Column(
          children: [
            Expanded(flex: 2, child: _buildCell(0)),
            SizedBox(height: _spacing),
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  Expanded(child: _buildCell(1)),
                  SizedBox(width: _spacing),
                  Expanded(child: _buildCell(2)),
                  SizedBox(width: _spacing),
                  Expanded(child: _buildCell(3)),
                ],
              ),
            ),
          ],
        );
      }
    } else if (n == 5) {
      // 5 photos: 2 Top + 3 Bottom
      return Column(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(child: _buildCell(0)),
                SizedBox(width: _spacing),
                Expanded(child: _buildCell(1)),
              ],
            ),
          ),
          SizedBox(height: _spacing),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(child: _buildCell(2)),
                SizedBox(width: _spacing),
                Expanded(child: _buildCell(3)),
                SizedBox(width: _spacing),
                Expanded(child: _buildCell(4)),
              ],
            ),
          ),
        ],
      );
    } else {
      // 6 photos: 2x3 or 3x2
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildCell(0)),
                SizedBox(width: _spacing),
                Expanded(child: _buildCell(1)),
                SizedBox(width: _spacing),
                Expanded(child: _buildCell(2)),
              ],
            ),
          ),
          SizedBox(height: _spacing),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildCell(3)),
                SizedBox(width: _spacing),
                Expanded(child: _buildCell(4)),
                SizedBox(width: _spacing),
                Expanded(child: _buildCell(5)),
              ],
            ),
          ),
        ],
      );
    }
  }

  Widget _buildCell(int index) {
    if (index >= _selectedItems.length) return const SizedBox.shrink();
    final item = _selectedItems[index];
    final bytes = _loadedImages[item.localId];

    return ClipRRect(
      borderRadius: BorderRadius.circular(_borderRadius),
      child: bytes != null
          ? Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          : Container(
              color: Colors.white12,
              child: const Center(
                child: Icon(Icons.image, color: Colors.white38),
              ),
            ),
    );
  }

  Widget _buildControlsPanel(AppThemeColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        border: Border(top: BorderSide(color: c.glassBorderSubtle, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Aspect Ratio & Layout Switcher Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Ratio Buttons
              Row(
                children: CollageAspectRatio.values.map((ratio) {
                  final isSelected = _aspectRatio == ratio;
                  return GestureDetector(
                    onTap: () => setState(() => _aspectRatio = ratio),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? c.primary : c.surfaceGlassFloating,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        ratio.label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : c.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Layout Toggle
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minSize: 0,
                onPressed: () {
                  setState(() {
                    _layoutStyle = (_layoutStyle + 1) % 2;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: c.surfaceGlassFloating,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.glassBorder, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.dashboard_customize_rounded, color: c.primary, size: 16),
                      const SizedBox(width: 4),
                      Text('Layout', style: TextStyle(color: c.primary, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Spacing & Corner Radius Sliders
          Row(
            children: [
              Icon(Icons.border_all_rounded, color: c.textTertiary, size: 18),
              const SizedBox(width: 6),
              Text('Gap', style: TextStyle(color: c.textSecondary, fontSize: 11)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: c.primary,
                    inactiveTrackColor: Colors.white12,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    trackHeight: 2,
                  ),
                  child: Slider(
                    value: _spacing,
                    min: 0.0,
                    max: 18.0,
                    onChanged: (val) => setState(() => _spacing = val),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.rounded_corner_rounded, color: c.textTertiary, size: 18),
              const SizedBox(width: 6),
              Text('Radius', style: TextStyle(color: c.textSecondary, fontSize: 11)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: c.primary,
                    inactiveTrackColor: Colors.white12,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    trackHeight: 2,
                  ),
                  child: Slider(
                    value: _borderRadius,
                    min: 0.0,
                    max: 24.0,
                    onChanged: (val) => setState(() => _borderRadius = val),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Frame Background Colors
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Colors.black,
              Colors.white,
              const Color(0xFF10141D),
              const Color(0xFF477BFF),
              const Color(0xFF55D6A0),
              const Color(0xFFFF747E),
            ].map((color) {
              final isSel = _backgroundColor == color;
              return GestureDetector(
                onTap: () => setState(() => _backgroundColor = color),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 24,
                  height: 24,
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
        ],
      ),
    );
  }
}
