import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../services/favorites_service.dart';
import '../../services/media_scanner_service.dart';
import '../screens/media_preview_screen.dart';
import 'three_d_touch_card.dart';

class MediaItemTile extends StatelessWidget {
  final MediaItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelectionMode;
  final bool isSelected;
  final bool showBackupStatus;

  const MediaItemTile({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.showBackupStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    final isFavorite = FavoritesService.instance.isFavorite(item.localId);
    final isUploaded = item.uploadState == UploadState.UPLOADED;

    return ThreeDTouchCard(
      onTap: onTap ??
          () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MediaPreviewScreen.single(item: item),
                ),
              ),
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(14),
      pressScale: 0.955,
      maxTiltAngle: 0.08,
      isSelected: isSelected,
      glowColor: AppTheme.primaryAccent,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryAccent
                : Colors.white.withOpacity(0.09),
            width: isSelected ? 1.8 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.04),
              blurRadius: 1,
              offset: const Offset(-0.5, -0.5),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail
            FutureBuilder<Uint8List?>(
              future: MediaScannerService.instance.getThumbnail(item.localId, size: 320),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.data != null &&
                    snapshot.data!.isNotEmpty) {
                  return Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                  );
                }
                return _buildPlaceholder();
              },
            ),

            // Subtle top shadow gradient for badges visibility
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 36,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Top-Left: Cloud backup badge (if uploaded)
            if (showBackupStatus && isUploaded)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.emeraldGreen.withOpacity(0.6),
                      width: 0.8,
                    ),
                  ),
                  child: const Icon(
                    Icons.cloud_done_rounded,
                    size: 11,
                    color: AppTheme.emeraldGreen,
                  ),
                ),
              ),

            // Top-Right: Favorite Heart (if favorited)
            if (isFavorite && !isSelectionMode)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.roseDanger.withOpacity(0.5),
                      width: 0.8,
                    ),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    size: 11,
                    color: AppTheme.roseDanger,
                  ),
                ),
              ),

            // Selection Mode Indicator (Top-Right)
            if (isSelectionMode)
              Positioned(
                top: 6,
                right: 6,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppTheme.primaryAccent
                        : Colors.black.withOpacity(0.45),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryAccent.withOpacity(0.5),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.black)
                      : null,
                ),
              ),

            // Bottom-Right: Video Duration Pill
            if (item.mediaType == AppMediaType.video)
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                      width: 0.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.play_arrow_rounded,
                        size: 11,
                        color: AppTheme.primaryAccent,
                      ),
                      if (item.durationSeconds != null && item.durationSeconds! > 0) ...[
                        const SizedBox(width: 2),
                        Text(
                          item.formattedDuration,
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
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
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.darkCardElevated,
      child: Center(
        child: Icon(
          item.mediaType == AppMediaType.video
              ? Icons.videocam_outlined
              : Icons.image_outlined,
          color: Colors.white24,
          size: 26,
        ),
      ),
    );
  }
}
