import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../models/media_item.dart';
import '../../services/media_scanner_service.dart';
import '../screens/media_preview_screen.dart';

class MediaItemTile extends StatelessWidget {
  final MediaItem item;
  final VoidCallback? onTap;

  const MediaItemTile({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ??
          () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MediaPreviewScreen(item: item),
                ),
              ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 0.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail
            FutureBuilder<Uint8List?>(
              future: MediaScannerService.instance.getThumbnail(item.localId, size: 300),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.data != null) {
                  return Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                  );
                }
                return Container(
                  color: Colors.white.withOpacity(0.05),
                  child: Center(
                    child: Icon(
                      item.mediaType == AppMediaType.video
                          ? Icons.videocam_outlined
                          : Icons.image_outlined,
                      color: Colors.white24,
                      size: 28,
                    ),
                  ),
                );
              },
            ),

            // Video indicator and duration at bottom-right
            if (item.mediaType == AppMediaType.video)
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow_rounded, size: 12, color: Colors.white),
                      if (item.durationSeconds != null && item.durationSeconds! > 0) ...[
                        const SizedBox(width: 2),
                        Text(
                          item.formattedDuration,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
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
}
