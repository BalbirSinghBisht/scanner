import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../services/favorites_service.dart';
import '../screens/media_preview_screen.dart';
import 'cached_thumbnail_image.dart';

/// Motion Primitives Media Grid Tile:
/// Clean, edge-to-edge, unencumbered by clutter.
/// Features smooth spring scaling, Realtime Colors selection glows,
/// and frosted glass video and favorite indicators.
class MediaItemTile extends StatelessWidget {
  final MediaItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelectionMode;
  final bool isSelected;

  const MediaItemTile({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final isFavorite = FavoritesService.instance.isFavorite(item.localId);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 0,
      pressedOpacity: 0.88,
      onPressed: onTap ??
          () => Navigator.push(
                context,
                PageRouteBuilder(
                  opaque: false,
                  barrierColor: Colors.black,
                  reverseTransitionDuration: Duration.zero,
                  pageBuilder: (_, _, _) => MediaPreviewScreen.single(item: item),
                  transitionsBuilder: (_, animation, _, child) =>
                      FadeTransition(opacity: animation, child: child),
                  transitionDuration: const Duration(milliseconds: 180),
                ),
              ),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: AnimatedScale(
          scale: isSelected ? 0.93 : 1.0,
          duration: AppTheme.motionFast,
          curve: AppTheme.springCurve,
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: c.primary, width: 2.2)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: c.primary.withOpacity(0.40),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Clean Image Thumbnail
                Hero(
                  tag: 'media_tile_${item.localId}',
                  child: CachedThumbnailImage(
                    localId: item.localId,
                    size: 400,
                    fit: BoxFit.cover,
                    placeholder: _buildPlaceholder(c),
                  ),
                ),

                // Selection Checkmark (Top-Right)
                if (isSelectionMode)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: AnimatedContainer(
                      duration: AppTheme.motionFast,
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? c.primary
                            : Colors.black.withOpacity(0.40),
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),

                // Subtle Favorite Heart (Bottom-Left)
                if (isFavorite && !isSelectionMode)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.all(3.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.20),
                              width: 0.5,
                            ),
                          ),
                          child: const Icon(
                            CupertinoIcons.heart_fill,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Video Duration Frosted Pill (Bottom-Right)
                if (item.mediaType == AppMediaType.video)
                  Positioned(
                    bottom: 5,
                    right: 5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.22),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.play_fill,
                                size: 8,
                                color: Colors.white,
                              ),
                              if (item.durationSeconds != null &&
                                  item.durationSeconds! > 0) ...[
                                const SizedBox(width: 3),
                                Text(
                                  item.formattedDuration,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                              ],
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
  }

  Widget _buildPlaceholder(AppThemeColors c) {
    return Container(
      color: c.surfaceElevated,
      child: Center(
        child: Icon(
          item.mediaType == AppMediaType.video
              ? CupertinoIcons.video_camera
              : CupertinoIcons.photo,
          color: c.textTertiary,
          size: 22,
        ),
      ),
    );
  }
}
