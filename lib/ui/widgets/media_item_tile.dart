import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../services/favorites_service.dart';
import '../screens/media_preview_screen.dart';
import 'cached_thumbnail_image.dart';

/// Liquidmorphism Media Grid Tile:
/// Clean edge-to-edge layout with organic spring dynamics, dynamic selection
/// ripple, frosted liquid glass badges, and specular rim highlights.
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

    // Target scale when pressed or selected
    final double targetScale = widget.isSelected
        ? 0.92
        : (_isPressed ? 0.95 : 1.0);

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
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(10),
              border: widget.isSelected
                  ? Border.all(color: c.primary, width: 2.4)
                  : Border.all(color: c.glassBorderSubtle, width: 0.5),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: c.primary.withOpacity(0.45),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(c.isDark ? 0.16 : 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
                    size: 400,
                    fit: BoxFit.cover,
                    placeholder: _buildPlaceholder(c),
                  ),
                ),

                // Top Specular Glass Sheen
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 1.2,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.40),
                          Colors.white.withOpacity(0.10),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Selection Checkmark & Liquid Ring (Top-Right)
                if (widget.isSelectionMode)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isSelected
                            ? c.primary
                            : Colors.black.withOpacity(0.42),
                        border: Border.all(
                          color: Colors.white,
                          width: 1.6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.isSelected
                                ? c.primary.withOpacity(0.50)
                                : Colors.black.withOpacity(0.35),
                            blurRadius: widget.isSelected ? 8 : 4,
                          ),
                        ],
                      ),
                      child: widget.isSelected
                          ? const Icon(
                              Icons.check,
                              size: 15,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),

                // Subtle Favorite Heart (Bottom-Left)
                if (isFavorite && !widget.isSelectionMode)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(4.0),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.48),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.24),
                              width: 0.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: c.accentRose.withOpacity(0.3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(
                            CupertinoIcons.heart_fill,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Video Duration Frosted Liquid Pill (Bottom-Right)
                if (widget.item.mediaType == AppMediaType.video)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.58),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.24),
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
                              if (widget.item.durationSeconds != null &&
                                  widget.item.durationSeconds! > 0) ...[
                                const SizedBox(width: 3.5),
                                Text(
                                  widget.item.formattedDuration,
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
