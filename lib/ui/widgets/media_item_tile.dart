import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../services/media_scanner_service.dart';

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
      onTap: onTap ?? () => _showMetadataDialog(context, item),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail
            FutureBuilder<Uint8List?>(
              future: MediaScannerService.instance.getThumbnail(item.localId),
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
                      color: Colors.white30,
                      size: 32,
                    ),
                  ),
                );
              },
            ),

            // Top gradient overlay for badges
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Bottom gradient overlay for info
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fileName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.formattedSize,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                          ),
                        ),
                        if (item.durationSeconds != null &&
                            item.durationSeconds! > 0)
                          Text(
                            item.formattedDuration,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // State Badge top-right
            Positioned(
              top: 6,
              right: 6,
              child: _buildStateBadge(item.uploadState),
            ),

            // Media Type Icon top-left
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  item.mediaType == AppMediaType.video
                      ? Icons.videocam
                      : Icons.photo,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateBadge(UploadState state) {
    Color bg;
    IconData icon;
    switch (state) {
      case UploadState.UPLOADED:
        bg = AppTheme.emeraldGreen;
        icon = Icons.check_circle;
        break;
      case UploadState.UPLOADING:
        bg = AppTheme.primaryAccent;
        icon = Icons.cloud_upload;
        break;
      case UploadState.FAILED:
        bg = AppTheme.roseDanger;
        icon = Icons.error;
        break;
      case UploadState.READY_TO_UPLOAD:
      case UploadState.RETRY_PENDING:
        bg = Colors.blueGrey;
        icon = Icons.schedule;
        break;
      case UploadState.SKIPPED:
        bg = AppTheme.amberWarning;
        icon = Icons.skip_next;
        break;
      default:
        bg = Colors.grey;
        icon = Icons.circle_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            state.name.replaceAll('_', ' '),
            style: const TextStyle(
              fontSize: 9,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showMetadataDialog(BuildContext context, MediaItem item) {
    final df = DateFormat('MMM dd, yyyy HH:mm');
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      item.mediaType == AppMediaType.video
                          ? Icons.videocam
                          : Icons.image,
                      color: AppTheme.primaryAccent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.fileName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _metaRow('Status', item.uploadState.name),
                _metaRow('Size', item.formattedSize),
                if (item.formattedDimensions.isNotEmpty)
                  _metaRow('Dimensions', item.formattedDimensions),
                if (item.formattedDuration.isNotEmpty)
                  _metaRow('Duration', item.formattedDuration),
                _metaRow('MIME Type', item.mimeType),
                _metaRow('Created', df.format(item.createdAt)),
                if (item.modifiedAt != null)
                  _metaRow('Modified', df.format(item.modifiedAt!)),
                if (item.contentHash != null)
                  _metaRow('SHA-256 Hash', item.contentHash!, isMono: true),
                if (item.driveFileId != null)
                  _metaRow('Drive File ID', item.driveFileId!, isMono: true),
                _metaRow(
                  'Backup Path',
                  item.computeTargetFolderPath(),
                  isMono: true,
                ),
                if (item.errorMessage != null)
                  _metaRow('Error', item.errorMessage!, isError: true),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _metaRow(
    String label,
    String value, {
    bool isMono = false,
    bool isError = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isError ? AppTheme.roseDanger : Colors.white,
                fontFamily: isMono ? 'monospace' : null,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
