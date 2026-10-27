import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../screens/media_preview_screen.dart';
import 'cached_thumbnail_image.dart';

/// Apple Photos "Memories & Featured" Showcase Carousel:
/// Features clean, rounded iOS cards with smooth depth and native typography.
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

    final featuredItems = widget.items.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Apple Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    CupertinoIcons.sparkles,
                    size: 16,
                    color: AppTheme.appleBlue,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Featured Photos',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
                  child: const Text(
                    'Hide',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.appleBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Apple Carousel Cards
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _pageController,
            itemCount: featuredItems.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final item = featuredItems[index];
              final diff = index - _currentPage;

              final scale = (1.0 - (diff.abs() * 0.08)).clamp(0.88, 1.0);
              final opacity = (1.0 - (diff.abs() * 0.25)).clamp(0.5, 1.0);

              final df = DateFormat('MMMM d');

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
                        color: AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
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
                            size: 600,
                            fit: BoxFit.cover,
                            placeholder: Container(
                              color: AppTheme.darkCard,
                              child: const Center(
                                child: Icon(
                                  CupertinoIcons.photo,
                                  color: Colors.white24,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),

                          // Gradient Vignette
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.1),
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.35),
                                    Colors.black.withOpacity(0.75),
                                  ],
                                  stops: const [0.0, 0.4, 0.7, 1.0],
                                ),
                              ),
                            ),
                          ),

                          // Video Indicator
                          if (item.mediaType == AppMediaType.video)
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      CupertinoIcons.play_fill,
                                      size: 9,
                                      color: Colors.white,
                                    ),
                                    if (item.durationSeconds != null) ...[
                                      const SizedBox(width: 3),
                                      Text(
                                        item.formattedDuration,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                          // Bottom Title & Date (Apple Photos style)
                          Positioned(
                            left: 14,
                            right: 14,
                            bottom: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  df.format(item.createdAt).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.7),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.displayFolderName,
                                  style: const TextStyle(
                                    fontSize: 16,
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
