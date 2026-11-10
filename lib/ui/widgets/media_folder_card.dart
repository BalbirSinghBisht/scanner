import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import 'cached_thumbnail_image.dart';
import 'three_d_touch_card.dart';

/// Apple Photos Album Card:
/// Authentic iOS Photos album presentation with continuous squircle corners,
/// elegant Apple typography hierarchy, subtle layered depth, and native haptic press physics.
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
      borderRadius: BorderRadius.circular(14),
      maxTiltAngle: 0.04,
      pressScale: 0.96,
      glowColor: isAll ? c.primary : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Album Photo Cover (Square 1:1 with Apple continuous corners)
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: c.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isAll
                      ? c.primary.withOpacity(0.35)
                      : c.glassBorderSubtle,
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: c.isDark
                        ? const Color(0x59000000)
                        : const Color(0x14000000),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverItem != null)
                    CachedThumbnailImage(
                      localId: coverItem!.localId,
                      filePath: coverItem!.localFilePath,
                      isVideo: coverItem!.isVideo,
                      size: 500,
                      fit: BoxFit.cover,
                      placeholder: _buildPlaceholder(c),
                    )
                  else
                    _buildPlaceholder(c),

                  // Subtle gradient sheen
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(c.isDark ? 0.25 : 0.40),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Apple Photos Album Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              isAll ? 'Recents' : folderName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 1),

          // Apple Photos Album Count Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              isAll ? '$itemCount items' : '$itemCount',
              style: TextStyle(
                fontSize: 13,
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
