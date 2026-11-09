import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/media_scanner_service.dart';

/// Ultra-Fast Hardware-Accelerated Cached Thumbnail Image:
/// - Uses native C++ image decoding (cacheWidth/cacheHeight) for local files, bypassing heavy Dart memory byte arrays.
/// - Loads crisp, downsampled 240px thumbnails for videos and MediaStore assets.
/// - Zero animation overhead: no per-tile ticker controllers or heavy ShaderMask offscreen passes.
class CachedThumbnailImage extends StatefulWidget {
  final String localId;
  final String? filePath;
  final bool isVideo;
  final int size;
  final BoxFit fit;
  final Widget placeholder;

  const CachedThumbnailImage({
    super.key,
    required this.localId,
    this.filePath,
    this.isVideo = false,
    this.size = 400,
    this.fit = BoxFit.cover,
    required this.placeholder,
  });

  @override
  State<CachedThumbnailImage> createState() => _CachedThumbnailImageState();
}

class _CachedThumbnailImageState extends State<CachedThumbnailImage> {
  Uint8List? _bytes;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Fast-path: local images are handled natively by Flutter's Image.file
    if (!widget.isVideo && widget.filePath != null && widget.filePath!.isNotEmpty) {
      return;
    }

    _bytes = MediaScannerService.instance
        .getCachedThumbnail(widget.localId, size: widget.size);
    if (_bytes == null) {
      _loadThumbnail();
    }
  }

  @override
  void didUpdateWidget(CachedThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localId != widget.localId ||
        oldWidget.filePath != widget.filePath ||
        oldWidget.size != widget.size ||
        oldWidget.isVideo != widget.isVideo) {
      _hasError = false;
      if (!widget.isVideo && widget.filePath != null && widget.filePath!.isNotEmpty) {
        return;
      }
      _bytes = MediaScannerService.instance
          .getCachedThumbnail(widget.localId, size: widget.size);
      if (_bytes == null) {
        _loadThumbnail();
      }
    }
  }

  Future<void> _loadThumbnail() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      final data = await MediaScannerService.instance
          .getThumbnail(widget.localId, size: widget.size, quality: 80);
      if (mounted) {
        setState(() {
          _bytes = data;
          _isLoading = false;
          _hasError = data == null || data.isEmpty;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);

    // 1. Direct hardware-decoded file rendering for images with local file path
    if (!widget.isVideo && widget.filePath != null && widget.filePath!.isNotEmpty) {
      final file = File(widget.filePath!);
      return Image.file(
        file,
        fit: widget.fit,
        cacheWidth: widget.size,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          // If direct file access fails, fall back to memory bytes or placeholder
          if (_bytes != null && _bytes!.isNotEmpty) {
            return Image.memory(
              _bytes!,
              fit: widget.fit,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (ctx, err, stack) => widget.placeholder,
            );
          }
          _loadThumbnail();
          return widget.placeholder;
        },
      );
    }

    // 2. Video thumbnail or MediaStore asset from memory cache
    if (_bytes != null && _bytes!.isNotEmpty) {
      return Image.memory(
        _bytes!,
        fit: widget.fit,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) =>
            _buildErrorState(c),
      );
    }

    // 3. Error state
    if (_hasError) {
      return widget.placeholder;
    }

    // 4. Loading state: return placeholder immediately without GPU-heavy ShaderMask
    return widget.placeholder;
  }

  Widget _buildErrorState(AppThemeColors c) {
    return Container(
      color: c.surfaceElevated,
      child: Center(
        child: Icon(
          Icons.broken_image_rounded,
          color: c.textTertiary.withOpacity(0.5),
          size: 24,
        ),
      ),
    );
  }
}
