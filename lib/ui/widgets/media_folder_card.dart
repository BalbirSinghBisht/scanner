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
  final bool isLocked;
  final IconData? customIcon;
  final Color? customAccentColor;
  final String? customSubtitle;
  final VoidCallback onTap;

  const MediaFolderCard({
    super.key,
    required this.folderName,
    required this.itemCount,
    this.coverItem,
    this.isAll = false,
    this.isLocked = false,
    this.customIcon,
    this.customAccentColor,
    this.customSubtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final accent = customAccentColor ??
        (isLocked
            ? const Color(0xFFE5A93B)
            : (isAll ? c.primary : null));

    return ThreeDTouchCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      maxTiltAngle: 0.04,
      pressScale: 0.96,
      glowColor: accent != null ? accent.withOpacity(0.3) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Album Photo Cover (Square 1:1 with Apple continuous corners)
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: c.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: accent != null
                      ? accent.withOpacity(0.35)
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
                  if (coverItem != null && !isLocked && customIcon == null)
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
              isLocked
                  ? 'Private Folder'
                  : (isAll ? 'Recents' : folderName),
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
              customSubtitle ??
                  (isLocked
                      ? 'Locked • PIN'
                      : (isAll ? '$itemCount items' : '$itemCount')),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: accent ?? c.textSecondary,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(AppThemeColors c) {
    if (customIcon != null && customAccentColor != null) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              customAccentColor!.withOpacity(0.25),
              c.isDark ? const Color(0xFF14191F) : const Color(0xFFE8ECEF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: customAccentColor!.withOpacity(0.18),
              border: Border.all(
                color: customAccentColor!.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Icon(
              customIcon,
              color: customAccentColor,
              size: 32,
            ),
          ),
        ),
      );
    }

    if (isLocked) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFE5A93B).withOpacity(0.22),
              const Color(0xFF1E170E),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE5A93B).withOpacity(0.18),
              border: Border.all(
                color: const Color(0xFFE5A93B).withOpacity(0.4),
                width: 1,
              ),
            ),
            child: const Icon(
              CupertinoIcons.lock_shield_fill,
              color: Color(0xFFE5A93B),
              size: 32,
            ),
          ),
        ),
      );
    }
    return Container(
      color: c.surfaceElevated,
      child: Center(
        child: Icon(
          isAll ? CupertinoIcons.photo_on_rectangle : CupertinoIcons.folder,
          color: c.textTertiary,
          size: 26,
        ),
      ),
    );
  }
}
