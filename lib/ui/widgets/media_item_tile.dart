import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../services/favorites_service.dart';
import '../screens/media_preview_screen.dart';
import 'cached_thumbnail_image.dart';

/// Apple Photos Grid Item Tile:
/// Authentic iOS Photos item presentation with edge-to-edge precision,
/// native Apple selection checkmarks, subtle interactive scale physics,
/// video duration pill badges, and favorite indicators.
class MediaItemTile extends StatefulWidget {
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
  State<MediaItemTile> createState() => _MediaItemTileState();
}

class _MediaItemTileState extends State<MediaItemTile>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final isFavorite = FavoritesService.instance.isFavorite(widget.item.localId);

    // Apple subtle interactive scale
    final double targetScale = widget.isSelected
        ? 0.94
        : (_isPressed ? 0.97 : 1.0);

    return Listener(
      onPointerDown: (_) => setState(() => _isPressed = true),
      onPointerUp: (_) => setState(() => _isPressed = false),
      onPointerCancel: (_) => setState(() => _isPressed = false),
      child: GestureDetector(
        onTap: widget.onTap ??
            () => Navigator.push(
                  context,
                  PageRouteBuilder(
                    opaque: false,
                    barrierColor: Colors.black,
                    reverseTransitionDuration: Duration.zero,
                    pageBuilder: (_, _, _) => MediaPreviewScreen.single(item: widget.item),
                    transitionsBuilder: (_, animation, _, child) =>
                        FadeTransition(opacity: animation, child: child),
                    transitionDuration: const Duration(milliseconds: 180),
                  ),
                ),
        onLongPress: widget.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: targetScale,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: Container(
            decoration: BoxDecoration(
              color: c.surfaceElevated,
              borderRadius: BorderRadius.circular(widget.isSelected ? 8 : 4),
              border: widget.isSelected
                  ? Border.all(color: c.primary, width: 2.5)
                  : null,
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: c.primary.withOpacity(0.35),
                        blurRadius: 8,
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
                  tag: 'media_tile_${widget.item.localId}',
                  child: CachedThumbnailImage(
                    localId: widget.item.localId,
                    filePath: widget.item.localFilePath,
                    isVideo: widget.item.isVideo,
                    size: 280,
                    fit: BoxFit.cover,
                    placeholder: _buildPlaceholder(c),
                  ),
                ),

                // Subtle Bottom Gradient Vignette for text readability
                if (widget.item.mediaType == AppMediaType.video || isFavorite)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 36,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Color(0x80000000),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                // Apple Photos Selection Circle (Top-Right)
                if (widget.isSelectionMode)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isSelected
                            ? c.primary
                            : const Color(0x33000000),
                        border: Border.all(
                          color: Colors.white,
                          width: widget.isSelected ? 1.5 : 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: widget.isSelected
                          ? const Center(
                              child: Icon(
                                CupertinoIcons.checkmark,
                                size: 13,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),

                // Subtle Favorite Heart (Bottom-Left)
                if (isFavorite && !widget.isSelectionMode)
                  const Positioned(
                    bottom: 5,
                    left: 6,
                    child: Icon(
                      CupertinoIcons.heart_fill,
                      size: 13,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Color(0x80000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),

                // Video Duration Badge (Bottom-Right)
                if (widget.item.mediaType == AppMediaType.video)
                  Positioned(
                    bottom: 5,
                    right: 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.play_fill,
                          size: 9,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Color(0x99000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        if (widget.item.durationSeconds != null &&
                            widget.item.durationSeconds! > 0) ...[
                          const SizedBox(width: 3),
                          Text(
                            widget.item.formattedDuration,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              shadows: [
                                Shadow(
                                  color: Color(0x99000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
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
          widget.item.mediaType == AppMediaType.video
              ? CupertinoIcons.video_camera
              : CupertinoIcons.photo,
          color: c.textTertiary,
          size: 22,
        ),
      ),
    );
  }
}
