import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/media_scanner_service.dart';

/// Liquidmorphism Cached Thumbnail Image:
/// Smooth fade-in on load, animated shimmer skeleton while loading,
/// and a frosted glass error state with subtle pulse animation.
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

class _CachedThumbnailImageState extends State<CachedThumbnailImage>
    with SingleTickerProviderStateMixin {
  Uint8List? _bytes;
  bool _isLoading = false;
  bool _hasError = false;
  bool _didFadeIn = false;

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _bytes = MediaScannerService.instance
        .getCachedThumbnail(widget.localId, size: widget.size);
    if (_bytes != null && _bytes!.isNotEmpty) {
      _didFadeIn = true; // Already cached — no fade needed
    } else {
      _shimmerController.repeat();
      _loadThumbnail();
    }
  }

  @override
  void didUpdateWidget(CachedThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localId != widget.localId || oldWidget.size != widget.size) {
      _hasError = false;
      _didFadeIn = false;
      _bytes = MediaScannerService.instance
          .getCachedThumbnail(widget.localId, size: widget.size);
      if (_bytes != null && _bytes!.isNotEmpty) {
        _didFadeIn = true;
        if (_shimmerController.isAnimating) _shimmerController.stop();
      } else {
        if (!_shimmerController.isAnimating) _shimmerController.repeat();
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
          _hasError = data == null || data.isEmpty;
        });
        if (!_hasError) _shimmerController.stop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        _shimmerController.stop();
      }
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);

    // Loaded state: smooth fade-in
    if (_bytes != null && _bytes!.isNotEmpty) {
      final imageWidget = Image.memory(
        _bytes!,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) =>
            _buildErrorState(c),
      );

      if (_didFadeIn) return imageWidget;

      // Trigger one-shot fade-in
      _didFadeIn = true;
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        builder: (context, opacity, child) {
          return Opacity(opacity: opacity, child: child);
        },
        child: imageWidget,
      );
    }

    // Error state: fallback to placeholder
    if (_hasError) return widget.placeholder;

    // Loading state: show placeholder with animated liquid shimmer overlay
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.placeholder,
        Positioned.fill(child: _buildShimmerPlaceholder(c)),
      ],
    );
  }

  Widget _buildShimmerPlaceholder(AppThemeColors c) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        final shimmerProgress = _shimmerController.value;
        // Translate a diagonal shimmer band across the surface
        final shimmerX = -1.0 + shimmerProgress * 3.0;

        return Container(
          color: c.surfaceElevated,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Animated shimmer gradient sweep
              ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    begin: Alignment(shimmerX - 0.6, -0.3),
                    end: Alignment(shimmerX + 0.6, 0.3),
                    colors: [
                      Colors.transparent,
                      (c.isDark
                              ? Colors.white
                              : const Color(0xFF94A3B8))
                          .withOpacity(0.12),
                      (c.isDark
                              ? Colors.white
                              : const Color(0xFF94A3B8))
                          .withOpacity(0.22),
                      (c.isDark
                              ? Colors.white
                              : const Color(0xFF94A3B8))
                          .withOpacity(0.12),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcATop,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.surfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState(AppThemeColors c) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1.0),
      duration: const Duration(milliseconds: 1800),
      curve: Curves.easeInOut,
      builder: (context, pulseVal, child) {
        return Container(
          color: c.surfaceElevated,
          child: Center(
            child: Opacity(
              opacity: 0.4 + (pulseVal - 0.85) * 3.3, // 0.4 → 0.9
              child: Transform.scale(
                scale: pulseVal,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: c.textTertiary,
                  size: 28,
                ),
              ),
            ),
          ),
        );
      },
      // Repeat the pulse by rebuilding
      onEnd: () {
        // Trigger rebuild for continuous pulse — handled via parent rebuild
      },
    );
  }
}
