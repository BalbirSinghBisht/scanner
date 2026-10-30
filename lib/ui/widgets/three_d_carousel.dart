import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../screens/media_preview_screen.dart';
import 'cached_thumbnail_image.dart';

/// Liquidmorphism 3D Featured Showcase Carousel:
/// Features dynamic 3D perspective rotation, floating fluid buoyancy,
/// aspect-ratio intelligent presentation (completely shows full photo & video
/// content without awkward cropping whether matching tray ratio or not),
/// animated liquid glass shimmer pills, and liquid morphing page dots.
class ThreeDShowcaseCarousel extends StatefulWidget {
  final List<MediaItem> items;
  final VoidCallback? onDismiss;

  const ThreeDShowcaseCarousel({
    super.key,
    required this.items,
    this.onDismiss,
  });

  @override
  State<ThreeDShowcaseCarousel> createState() => _ThreeDShowcaseCarouselState();
}

class _ThreeDShowcaseCarouselState extends State<ThreeDShowcaseCarousel>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  double _currentPage = 0.0;

  // Floating buoyancy oscillation
  late AnimationController _buoyancyController;

  // Auto-advance timer (pauses when touching)
  Timer? _autoAdvanceTimer;
  bool _isUserTouching = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.82,
      initialPage: 0,
    );

    _pageController.addListener(() {
      if (mounted) {
        setState(() {
          _currentPage = _pageController.page ?? 0.0;
        });
      }
    });

    _buoyancyController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _startAutoAdvance();
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!_isUserTouching && mounted && _pageController.hasClients) {
        final featuredCount = widget.items.take(10).length;
        if (featuredCount <= 1) return;
        final nextPage = ((_pageController.page ?? 0).round() + 1) % featuredCount;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 700),
          curve: AppTheme.liquidSpring,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    _buoyancyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final c = AppTheme.colors(context);
    final featuredItems = widget.items.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with Liquid Glow Sparkle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [c.primary, c.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: c.primary.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.sparkles,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Featured Photos & Videos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              if (widget.onDismiss != null)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: widget.onDismiss,
                  child: Text(
                    'Hide',
                    style: TextStyle(
                      fontSize: 14,
                      color: c.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 3D Carousel Cards with Perspective Rotation & Buoyancy
        Listener(
          onPointerDown: (_) {
            _isUserTouching = true;
          },
          onPointerUp: (_) {
            _isUserTouching = false;
          },
          onPointerCancel: (_) {
            _isUserTouching = false;
          },
          child: SizedBox(
            height: 228,
            child: PageView.builder(
              controller: _pageController,
              itemCount: featuredItems.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final item = featuredItems[index];
                final diff = index - _currentPage;

                final scale = (1.0 - (diff.abs() * 0.08)).clamp(0.85, 1.0);
                final opacity = (1.0 - (diff.abs() * 0.28)).clamp(0.40, 1.0);
                final rotateY = (diff * -0.12).clamp(-0.35, 0.35);

                // Floating liquid buoyancy oscillation
                final buoyancyOffset = 3.0 * math.sin((_buoyancyController.value * 2 * math.pi) + (index * 0.8));

                // 3D perspective matrix
                final transform = Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..translate(0.0, buoyancyOffset)
                  ..rotateY(rotateY)
                  ..scale(scale);

                return Transform(
                  transform: transform,
                  alignment: FractionalOffset.center,
                  child: Opacity(
                    opacity: opacity,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            opaque: false,
                            barrierColor: Colors.black,
                            reverseTransitionDuration: Duration.zero,
                            pageBuilder: (_, _, _) => MediaPreviewScreen(
                              items: widget.items,
                              initialIndex: widget.items.indexOf(item),
                            ),
                            transitionsBuilder: (_, animation, _, child) =>
                                FadeTransition(opacity: animation, child: child),
                            transitionDuration: const Duration(milliseconds: 180),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: c.glassBorderSpecular,
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(c.isDark ? 0.48 : 0.16),
                              blurRadius: 22,
                              offset: const Offset(0, 9),
                            ),
                            BoxShadow(
                              color: c.primary.withOpacity(c.isDark ? 0.18 : 0.10),
                              blurRadius: 18,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // ───────────────────────────────────────────────
                            // INTELLIGENT ASPECT-RATIO MEDIA PRESENTATION:
                            // Layer 1: Ambient Blurred Liquid Background (fills entire card)
                            // Layer 2: Complete Uncropped Sharp Media in exact ratio
                            // ───────────────────────────────────────────────
                            _buildMediaDisplay(item, c),

                            // Top Specular Glass Sheen
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 1.5,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.55),
                                      Colors.white.withOpacity(0.18),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Bottom Contrast Gradient for readable typography
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.08),
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.35),
                                      Colors.black.withOpacity(0.85),
                                    ],
                                    stops: const [0.0, 0.40, 0.70, 1.0],
                                  ),
                                ),
                              ),
                            ),

                            // Video Indicator Frosted Glass Badge with Duration
                            if (item.mediaType == AppMediaType.video)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.55),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.28),
                                          width: 0.6,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            CupertinoIcons.play_fill,
                                            size: 10,
                                            color: Colors.white,
                                          ),
                                          if (item.durationSeconds != null && item.durationSeconds! > 0) ...[
                                            const SizedBox(width: 4),
                                            Text(
                                              item.formattedDuration,
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // Ratio tag indicator if vertical/panoramic
                            if (_isVerticalMedia(item))
                              Positioned(
                                top: 12,
                                left: 12,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.45),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.20),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: const Text(
                                        'PORTRAIT',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // Bottom Title & Date in 3D Frosted Liquid Glass Pill
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.48),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.22),
                                        width: 0.6,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          DateFormat('MMMM d').format(item.createdAt).toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white.withOpacity(0.85),
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const SizedBox(height: 1.5),
                                        Text(
                                          item.displayFolderName,
                                          style: const TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: -0.3,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // ───────────────────────────────────────────────
        // LIQUID MORPHING PAGE DOTS
        // ───────────────────────────────────────────────
        if (featuredItems.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(featuredItems.length, (i) {
                final pageDiff = (i - _currentPage).abs();
                final isCurrent = pageDiff < 0.5;
                // Morph width smoothly from circle (6px) to liquid pill (22px)
                final dotWidth = isCurrent
                    ? uiLerp(22.0, 6.0, (pageDiff * 2).clamp(0.0, 1.0))
                    : 6.0;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 5.5,
                  width: dotWidth,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: isCurrent
                        ? c.primary
                        : (c.isDark ? Colors.white24 : Colors.black12),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  /// Linear interpolation helper
  double uiLerp(double a, double b, double t) => a + (b - a) * t;

  bool _isVerticalMedia(MediaItem item) {
    if (item.width != null && item.height != null && item.height! > 0) {
      return (item.height! / item.width!) > 1.25;
    }
    return false;
  }

  /// Builds adaptive media display:
  /// For items whose aspect ratio differs from the tray card (e.g. vertical videos,
  /// 9:16 stories, square photos, panoramic shots), it renders:
  /// 1. An ambient blurred backdrop that fills the card edge-to-edge.
  /// 2. An uncropped, crisp foreground photo/video with BoxFit.contain so 100% of the
  ///    content is completely and accurately shown without being cropped off!
  Widget _buildMediaDisplay(MediaItem item, AppThemeColors c) {
    final hasKnownDimensions = item.width != null && item.height != null && item.width! > 0 && item.height! > 0;
    // Typical carousel card ratio is ~ 310 / 215 ≈ 1.44 (landscape)
    final bool isMatchingLandscape = hasKnownDimensions &&
        (item.width! / item.height!) >= 1.25 &&
        (item.width! / item.height!) <= 1.70;

    if (isMatchingLandscape) {
      // Matches tray aspect ratio: fill cleanly
      return CachedThumbnailImage(
        localId: item.localId,
        size: 700,
        fit: BoxFit.cover,
        placeholder: _buildPlaceholder(c),
      );
    }

    // Different ratio (vertical portrait, square, panorama, etc.):
    // Display full media uncropped with ambient blurred backdrop!
    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 1: Ambient Blurred Liquid Canvas
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Transform.scale(
            scale: 1.25, // Scale up slightly to eliminate edge blur fade
            child: CachedThumbnailImage(
              localId: item.localId,
              size: 400,
              fit: BoxFit.cover,
              placeholder: Container(color: c.surfaceElevated),
            ),
          ),
        ),

        // Translucent liquid tint overlay
        ColoredBox(
          color: Colors.black.withOpacity(0.32),
        ),

        // Layer 2: Complete Sharp Media Display (BoxFit.contain preserves 100% full content)
        Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 48), // Padding so it floats cleanly above the bottom pill
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.40),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: CachedThumbnailImage(
                  localId: item.localId,
                  size: 750,
                  fit: BoxFit.contain, // COMPLETELY SHOWS ENTIRE PHOTO / VIDEO!
                  placeholder: _buildPlaceholder(c),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(AppThemeColors c) {
    return Container(
      color: c.surfaceElevated,
      child: Center(
        child: Icon(
          CupertinoIcons.photo,
          color: c.textTertiary,
          size: 32,
        ),
      ),
    );
  }
}
