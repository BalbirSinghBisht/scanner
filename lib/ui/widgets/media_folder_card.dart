import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import 'cached_thumbnail_image.dart';
import 'three_d_touch_card.dart';

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

  IconData _getFolderIcon() {
    if (isAll) return Icons.all_inclusive_rounded;
    final lower = folderName.toLowerCase();
    if (lower.contains('camera') || lower == 'dcim') return Icons.photo_camera_rounded;
    if (lower.contains('screenshot')) return Icons.smartphone_rounded;
    if (lower.contains('whatsapp')) return Icons.chat_bubble_outline_rounded;
    if (lower.contains('download')) return Icons.arrow_downward_rounded;
    if (lower.contains('instagram')) return Icons.camera_alt_outlined;
    if (lower.contains('video') || lower.contains('movie')) return Icons.videocam_rounded;
    if (lower.contains('favorite') || lower.contains('star')) return Icons.favorite_rounded;
    return Icons.folder_copy_rounded;
  }

  Color _getBadgeAccentColor() {
    if (isAll) return AppTheme.primaryAccent;
    final lower = folderName.toLowerCase();
    if (lower.contains('camera') || lower == 'dcim') return AppTheme.neonAzure;
    if (lower.contains('screenshot')) return AppTheme.electricViolet;
    if (lower.contains('whatsapp')) return AppTheme.emeraldGreen;
    if (lower.contains('download')) return AppTheme.amberWarning;
    if (lower.contains('favorite')) return AppTheme.roseDanger;
    return const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = _getBadgeAccentColor();

    return ThreeDTouchCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      maxTiltAngle: 0.08,
      pressScale: 0.965,
      glowColor: badgeColor,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. 3D Under-layer Card 1 (Refined subtle left tilt)
          Positioned.fill(
            child: Transform.rotate(
              angle: -0.038, // ~ -2.2 degrees
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.only(bottom: 6, left: 3, right: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF141F36),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. 3D Under-layer Card 2 (Refined subtle right tilt)
          Positioned.fill(
            child: Transform.rotate(
              angle: 0.026, // ~ +1.5 degrees
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.only(bottom: 3, left: 2, right: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF192642),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.10),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Top Main Photo Card
          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isAll
                    ? AppTheme.primaryAccent.withOpacity(0.5)
                    : Colors.white.withOpacity(0.14),
                width: isAll ? 1.6 : 1.0,
              ),
              boxShadow: AppTheme.depthShadow(
                depth: 10,
                glowColor: isAll ? AppTheme.primaryAccent : null,
                glowOpacity: 0.2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Cover Thumbnail with CachedThumbnailImage (zero flicker)
                if (coverItem != null)
                  CachedThumbnailImage(
                    localId: coverItem!.localId,
                    size: 400,
                    fit: BoxFit.cover,
                    placeholder: _buildPlaceholder(badgeColor),
                  )
                else
                  _buildPlaceholder(badgeColor),

                // Cinematic multi-stop gradient for text readability
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.15),
                          Colors.transparent,
                          Colors.black.withOpacity(0.4),
                          Colors.black.withOpacity(0.88),
                        ],
                        stops: const [0.0, 0.4, 0.65, 1.0],
                      ),
                    ),
                  ),
                ),

                // Top Specular Highlight Edge
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 1.2,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.4),
                          isAll
                              ? AppTheme.primaryAccent.withOpacity(0.8)
                              : Colors.white.withOpacity(0.4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Top-right Item Count Pill
                Positioned(
                  top: 10,
                  right: 10,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getFolderIcon(),
                              size: 11,
                              color: badgeColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isAll ? 'ALL' : '$itemCount',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withOpacity(0.95),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Frosted Glass Metadata Capsule
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF090F1C).withOpacity(0.82),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.14),
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4.5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        badgeColor.withOpacity(0.35),
                                        badgeColor.withOpacity(0.1),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: badgeColor.withOpacity(0.6),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Icon(
                                    _getFolderIcon(),
                                    size: 12,
                                    color: badgeColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    folderName,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.1,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Padding(
                              padding: const EdgeInsets.only(left: 25),
                              child: Text(
                                itemCount == 1 ? '1 item' : '$itemCount items',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.65),
                                  fontWeight: FontWeight.w500,
                                ),
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
    );
  }

  Widget _buildPlaceholder(Color accent) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.darkCardElevated,
            AppTheme.darkCard,
            AppTheme.darkBg,
          ],
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.04),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          child: Icon(
            _getFolderIcon(),
            size: 38,
            color: accent.withOpacity(0.7),
          ),
        ),
      ),
    );
  }
}
