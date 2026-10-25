import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../screens/media_preview_screen.dart';
import 'cached_thumbnail_image.dart';

/// A 3D Spatial Coverflow Carousel that displays featured media items
/// with realistic depth perspective, Y-axis rotation, and dynamic reflections.
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
      viewportFraction: 0.76,
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

    // Show up to 12 recent featured items
    final featuredItems = widget.items.take(12).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with 3D Pill and Dismiss/Toggle button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryAccent, AppTheme.electricViolet],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryAccent.withOpacity(0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 13,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Featured Moments',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              if (widget.onDismiss != null)
                InkWell(
                  onTap: widget.onDismiss,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Hide',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.keyboard_arrow_up_rounded,
                          size: 16,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 3D Perspective Carousel
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            itemCount: featuredItems.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final item = featuredItems[index];
              final diff = index - _currentPage;

              // 3D Perspective Transform
              final clampedDiff = diff.clamp(-2.0, 2.0);
              final rotationY = clampedDiff * 0.32; // In radians
              final scale = (1.0 - (diff.abs() * 0.12)).clamp(0.82, 1.0);
              final opacity = (1.0 - (diff.abs() * 0.35)).clamp(0.4, 1.0);

              final transform = Matrix4.identity()
                ..setEntry(3, 2, 0.0016) // Perspective depth
                ..rotateY(rotationY)
                ..scale(scale);

              final df = DateFormat('MMM d, yyyy');

              return Transform(
                transform: transform,
                alignment: diff > 0 ? Alignment.centerLeft : Alignment.centerRight,
                child: Opacity(
                  opacity: opacity,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MediaPreviewScreen(
                            items: widget.items,
                            initialIndex: widget.items.indexOf(item),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: diff.abs() < 0.5
                              ? AppTheme.primaryAccent.withOpacity(0.4)
                              : Colors.white.withOpacity(0.1),
                          width: diff.abs() < 0.5 ? 1.5 : 1.0,
                        ),
                        boxShadow: AppTheme.depthShadow(
                          depth: 10,
                          glowColor: diff.abs() < 0.5
                              ? AppTheme.primaryAccent
                              : null,
                          glowOpacity: 0.25,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // High-res cover image (flicker-free cached)
                          CachedThumbnailImage(
                            localId: item.localId,
                            size: 500,
                            fit: BoxFit.cover,
                            placeholder: Container(
                              color: AppTheme.darkCardElevated,
                              child: const Center(
                                child: Icon(
                                  Icons.photo_outlined,
                                  color: Colors.white24,
                                  size: 36,
                                ),
                              ),
                            ),
                          ),

                          // Dramatic 3D lighting vignette
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.2),
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.5),
                                    Colors.black.withOpacity(0.88),
                                  ],
                                  stops: const [0.0, 0.4, 0.7, 1.0],
                                ),
                              ),
                            ),
                          ),

                          // Top-right Video / Image Chip
                          if (item.mediaType == AppMediaType.video)
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.65),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.15),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.play_circle_fill_rounded,
                                      size: 13,
                                      color: AppTheme.primaryAccent,
                                    ),
                                    if (item.durationSeconds != null) ...[
                                      const SizedBox(width: 4),
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

                          // Bottom Metadata Pill
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.fileName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      df.format(item.createdAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '•  ${item.displayFolderName}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.primaryAccent,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
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
