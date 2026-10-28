import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../screens/media_preview_screen.dart';
import 'cached_thumbnail_image.dart';

/// Motion Primitives 3D Featured Showcase Carousel:
/// Features dynamic 3D perspective rotation, spring scaling, specular sheen,
/// and frosted glassmorphic typography pills with Realtime Colors.
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

class _ThreeDShowcaseCarouselState extends State<ThreeDShowcaseCarousel> {
  late PageController _pageController;
  double _currentPage = 0.0;

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
  }

  @override
  void dispose() {
    _pageController.dispose();
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
        // Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [c.primary, c.secondary],
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.sparkles,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Featured Photos',
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

        // 3D Carousel Cards with Perspective Rotation
        SizedBox(
          height: 215,
          child: PageView.builder(
            controller: _pageController,
            itemCount: featuredItems.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final item = featuredItems[index];
              final diff = index - _currentPage;

              final scale = (1.0 - (diff.abs() * 0.08)).clamp(0.86, 1.0);
              final opacity = (1.0 - (diff.abs() * 0.28)).clamp(0.45, 1.0);
              final rotateY = (diff * -0.12).clamp(-0.35, 0.35);

              final df = DateFormat('MMMM d');

              // 3D perspective matrix
              final transform = Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
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
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: c.glassBorderSpecular,
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(c.isDark ? 0.50 : 0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: c.primary.withOpacity(c.isDark ? 0.16 : 0.10),
                            blurRadius: 16,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Cover Image
                          CachedThumbnailImage(
                            localId: item.localId,
                            size: 650,
                            fit: BoxFit.cover,
                            placeholder: Container(
                              color: c.surfaceElevated,
                              child: Center(
                                child: Icon(
                                  CupertinoIcons.photo,
                                  color: c.textTertiary,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),

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
                                    Colors.white.withOpacity(0.50),
                                    Colors.white.withOpacity(0.15),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Contrast Vignette
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.12),
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.35),
                                    Colors.black.withOpacity(0.85),
                                  ],
                                  stops: const [0.0, 0.35, 0.65, 1.0],
                                ),
                              ),
                            ),
                          ),

                          // Video Indicator Frosted Glass Badge
                          if (item.mediaType == AppMediaType.video)
                            Positioned(
                              top: 10,
                              right: 10,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.55),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.25),
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
                                        if (item.durationSeconds != null) ...[
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

                          // Bottom Title & Date in 3D Frosted Glass Pill
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.45),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.20),
                                      width: 0.6,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        df.format(item.createdAt).toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white.withOpacity(0.80),
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        item.displayFolderName,
                                        style: const TextStyle(
                                          fontSize: 15,
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
      ],
    );
  }
}
