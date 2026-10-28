import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import 'cached_thumbnail_image.dart';
import 'three_d_touch_card.dart';

/// Motion Primitives 3D Album Card:
/// Features a 3D perspective touch tilt, stacked album depth layers,
/// specular glass frame sheen, and Realtime Colors typography.
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
      borderRadius: BorderRadius.circular(20),
      maxTiltAngle: 0.06,
      pressScale: 0.96,
      glowColor: c.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Album Photo Cover with 3D Stacked Frame
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Layer 2: Subtle secondary stacked card behind for true 3D depth
                Positioned(
                  top: -4,
                  left: 10,
                  right: 10,
                  bottom: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.surfaceElevated.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(18),
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
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: c.glassBorder,
                      width: 0.7,
                    ),
                    boxShadow: AppTheme.depthShadow(
                      depth: 8,
                      shadowColor: Colors.black,
                      glowColor: isAll ? c.primary : null,
                      glowOpacity: 0.12,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (coverItem != null)
                        CachedThumbnailImage(
                          localId: coverItem!.localId,
                          size: 450,
                          fit: BoxFit.cover,
                          placeholder: _buildPlaceholder(c),
                        )
                      else
                        _buildPlaceholder(c),

                      // Specular top glass sheen
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 1.5,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(c.isDark ? 0.40 : 0.60),
                                Colors.white.withOpacity(0.10),
                                Colors.transparent,
                              ],
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
          const SizedBox(height: 8),

          // Album Name
          Text(
            isAll ? 'Recents' : folderName,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1.5),

          // Photo & Video Count
          Text(
            '$itemCount',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: c.textSecondary,
              letterSpacing: -0.1,
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
