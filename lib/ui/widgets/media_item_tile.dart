import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../services/favorites_service.dart';
import '../screens/media_preview_screen.dart';
import 'cached_thumbnail_image.dart';

/// Apple Photos Grid Item Tile:
/// Clean, edge-to-edge, unencumbered by tags or badges.
/// Photos are presented purely with native iOS selection and video indicators.
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
    final isFavorite = FavoritesService.instance.isFavorite(item.localId);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 0,
      pressedOpacity: 0.85,
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
          scale: isSelected ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(4),
              border: isSelected
                  ? Border.all(color: AppTheme.appleBlue, width: 2.0)
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
                    placeholder: _buildPlaceholder(),
                  ),
                ),

                // Apple Selection Checkmark (Top-Right)
                if (isSelectionMode)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? AppTheme.appleBlue
                            : Colors.black.withOpacity(0.35),
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ),
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

                // Subtle Favorite Heart (if favorited and not selecting)
                if (isFavorite && !isSelectionMode)
                  Positioned(
                    bottom: 5,
                    left: 5,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.heart_fill,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),

                // Apple Video Duration Pill (Bottom-Right)
                if (item.mediaType == AppMediaType.video)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(4),
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
                                fontSize: 10,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.darkCard,
      child: Center(
        child: Icon(
          item.mediaType == AppMediaType.video
              ? CupertinoIcons.video_camera
              : CupertinoIcons.photo,
          color: Colors.white24,
          size: 22,
        ),
      ),
    );
  }
}
