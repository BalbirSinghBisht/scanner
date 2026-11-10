import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../screens/media_preview_screen.dart';
import 'cached_thumbnail_image.dart';

/// Apple Photos Featured Showcase Carousel:
/// Authentic iOS presentation with squircle curvature, aspect-ratio intelligent presentation,
/// Apple editorial typography, subtle ambient shadows, and native paging indicators.
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

  // Subtle floating oscillation
  late AnimationController _buoyancyController;

  // Auto-advance timer (pauses when touching)
  Timer? _autoAdvanceTimer;
  bool _isUserTouching = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.86,
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
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
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
        // Apple Photos Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    CupertinoIcons.sparkles,
                    size: 16,
                    color: c.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Featured',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                      letterSpacing: -0.4,
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
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Apple Carousel Cards
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
            height: 220,
            child: PageView.builder(
              controller: _pageController,
              itemCount: featuredItems.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final item = featuredItems[index];

                final pageOffset = (_currentPage - index);
                final absOffset = pageOffset.abs().clamp(0.0, 1.0);

                final scale = 1.0 - (absOffset * 0.05);
                final opacity = (1.0 - (absOffset * 0.20)).clamp(0.0, 1.0);

                return Transform.scale(
                  scale: scale,
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
                        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.surfaceElevated,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: c.glassBorderSubtle,
                            width: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: c.isDark
                                  ? const Color(0x66000000)
                                  : const Color(0x14000000),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Aspect-ratio intelligent media display
                            _buildMediaDisplay(item, c),

                            // Apple Vignette gradient for text contrast
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.30),
                                      Colors.black.withOpacity(0.75),
                                    ],
                                    stops: const [0.0, 0.45, 0.70, 1.0],
                                  ),
                                ),
                              ),
                            ),

                            // Video Indicator Badge with Duration
                            if (item.mediaType == AppMediaType.video)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.45),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            CupertinoIcons.play_fill,
                                            size: 9,
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

                            // Bottom Title & Date in Apple Photos style
                            Positioned(
                              left: 14,
                              right: 14,
                              bottom: 12,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    DateFormat('MMMM d').format(item.createdAt).toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.75),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.displayFolderName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: -0.3,
                                      shadows: [
                                        Shadow(
                                          color: Color(0x80000000),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
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

        // Apple Photos Page Indicator Dots
        if (featuredItems.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(featuredItems.length, (i) {
                final pageDiff = (i - _currentPage).abs();
                final isCurrent = pageDiff < 0.5;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  width: isCurrent ? 18 : 6,
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

  Widget _buildMediaDisplay(MediaItem item, AppThemeColors c) {
    final hasKnownDimensions = item.width != null && item.height != null && item.width! > 0 && item.height! > 0;
    final bool isMatchingLandscape = hasKnownDimensions &&
        (item.width! / item.height!) >= 1.25 &&
        (item.width! / item.height!) <= 1.70;

    if (isMatchingLandscape) {
      return CachedThumbnailImage(
        localId: item.localId,
        size: 700,
        fit: BoxFit.cover,
        placeholder: _buildPlaceholder(c),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Transform.scale(
            scale: 1.2,
            child: CachedThumbnailImage(
              localId: item.localId,
              size: 400,
              fit: BoxFit.cover,
              placeholder: Container(color: c.surfaceElevated),
            ),
          ),
        ),
        ColoredBox(
          color: Colors.black.withOpacity(0.25),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 44),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedThumbnailImage(
                localId: item.localId,
                size: 750,
                fit: BoxFit.contain,
                placeholder: _buildPlaceholder(c),
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
