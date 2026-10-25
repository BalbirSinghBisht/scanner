import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../services/media_scanner_service.dart';

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
    if (isAll) return Icons.photo_library_rounded;
    final lower = folderName.toLowerCase();
    if (lower.contains('camera') || lower == 'dcim') return Icons.camera_alt_rounded;
    if (lower.contains('screenshot')) return Icons.screenshot_rounded;
    if (lower.contains('whatsapp')) return Icons.chat_bubble_rounded;
    if (lower.contains('download')) return Icons.download_rounded;
    if (lower.contains('instagram')) return Icons.photo_camera_front_rounded;
    if (lower.contains('video')) return Icons.videocam_rounded;
    return Icons.folder_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAll
                ? AppTheme.primaryAccent.withOpacity(0.3)
                : AppTheme.darkCardBorder,
            width: isAll ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Folder Cover Image / Thumbnail
            if (coverItem != null)
              FutureBuilder<Uint8List?>(
                future: MediaScannerService.instance
                    .getThumbnail(coverItem!.localId, size: 360),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.data != null &&
                      snapshot.data!.isNotEmpty) {
                    return Image.memory(
                      snapshot.data!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _placeholder(),
                    );
                  }
                  return _placeholder();
                },
              )
            else
              _placeholder(),

            // Gradient overlay for contrast
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.15),
                      Colors.transparent,
                      Colors.black.withOpacity(0.5),
                      Colors.black.withOpacity(0.9),
                    ],
                    stops: const [0.0, 0.4, 0.7, 1.0],
                  ),
                ),
              ),
            ),

            // Folder details at the bottom
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isAll
                              ? AppTheme.primaryAccent.withOpacity(0.3)
                              : Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getFolderIcon(),
                          size: 15,
                          color: isAll ? AppTheme.primaryAccent : Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          folderName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: Text(
                      itemCount == 1 ? '1 item' : '$itemCount items',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppTheme.darkCard,
      child: Center(
        child: Icon(
          _getFolderIcon(),
          size: 46,
          color: Colors.white24,
        ),
      ),
    );
  }
}
