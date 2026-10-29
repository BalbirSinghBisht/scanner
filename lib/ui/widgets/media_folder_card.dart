import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import 'cached_thumbnail_image.dart';
import 'three_d_touch_card.dart';

/// Liquidmorphism 3D Album Card:
/// Features organic continuous curvature, floating layered glass depth stack,
/// dynamic specular sheen, and frosted liquid glass typography badge.
class MediaFolderCard extends StatelessWidget {
  final String folderName;
  final int itemCount;
  final MediaItem? coverItem;
  final bool isAll;
  final VoidCallback onTap;

  const MediaFolderCard({
    super.key,
    required this.folderName,
    required this.itemCount,
    this.coverItem,
    this.isAll = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);

    return ThreeDTouchCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      maxTiltAngle: 0.07,
      pressScale: 0.955,
      glowColor: isAll ? c.primary : c.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Album Photo Cover with 3D Stacked Liquid Frame
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Layer 3: Deepest stacked layer with subtle tilt
                Positioned(
                  top: -8,
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.surfaceElevated.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: c.glassBorderSubtle,
                        width: 0.5,
                      ),
                    ),
                  ),
                ),

                // Layer 2: Mid stacked layer
                Positioned(
                  top: -4,
                  left: 8,
                  right: 8,
                  bottom: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.surfaceElevated.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: c.glassBorderSubtle,
                        width: 0.6,
                      ),
                    ),
                  ),
                ),

                // Primary Album Photo Cover Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isAll
                          ? c.primary.withOpacity(0.40)
                          : c.glassBorder,
                      width: 0.8,
                    ),
                    boxShadow: AppTheme.depthShadow(
                      depth: 10,
                      shadowColor: Colors.black,
                      glowColor: isAll ? c.primary : null,
                      glowOpacity: 0.16,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (coverItem != null)
                        CachedThumbnailImage(
                          localId: coverItem!.localId,
                          size: 500,
                          fit: BoxFit.cover,
                          placeholder: _buildPlaceholder(c),
                        )
                      else
                        _buildPlaceholder(c),

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
                                Colors.white.withOpacity(c.isDark ? 0.45 : 0.65),
                                Colors.white.withOpacity(0.12),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Bottom Subtle Vignette for count badge
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.52),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.24),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isAll ? CupertinoIcons.photo_on_rectangle : CupertinoIcons.folder_fill,
                                    size: 10,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$itemCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
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
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Album Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              isAll ? 'Recents' : folderName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),

          // Photo & Video Count Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              isAll ? 'All media items' : '$itemCount items',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: c.textSecondary,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(AppThemeColors c) {
    return Container(
      color: c.surfaceElevated,
      child: Center(
        child: Icon(
          isAll ? CupertinoIcons.photo_on_rectangle : CupertinoIcons.folder,
          color: c.textTertiary,
          size: 32,
        ),
      ),
    );
  }
}
