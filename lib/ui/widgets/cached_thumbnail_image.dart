import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../services/media_scanner_service.dart';

/// A flicker-free thumbnail widget that retrieves cached in-memory bytes
/// synchronously on frame 0, prevents placeholder flashing on list scroll,
/// and enables gapless playback for butter-smooth 60/120 fps rendering.
class CachedThumbnailImage extends StatefulWidget {
  final String localId;
  final int size;
  final BoxFit fit;
  final Widget placeholder;

  const CachedThumbnailImage({
    super.key,
    required this.localId,
    this.size = 500,
    this.fit = BoxFit.cover,
    required this.placeholder,
  });

  @override
  State<CachedThumbnailImage> createState() => _CachedThumbnailImageState();
}

class _CachedThumbnailImageState extends State<CachedThumbnailImage> {
  Uint8List? _bytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _bytes = MediaScannerService.instance
        .getCachedThumbnail(widget.localId, size: widget.size);
    if (_bytes == null) {
      _loadThumbnail();
    }
  }

  @override
  void didUpdateWidget(CachedThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localId != widget.localId || oldWidget.size != widget.size) {
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
          .getThumbnail(widget.localId, size: widget.size, quality: 95);
      if (mounted) {
        setState(() {
          _bytes = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null && _bytes!.isNotEmpty) {
      return Image.memory(
        _bytes!,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => widget.placeholder,
      );
    }
    return widget.placeholder;
  }
}
