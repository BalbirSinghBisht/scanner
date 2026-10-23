import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/backup_provider.dart';

class ProgressIndicatorCard extends StatelessWidget {
  final BackupProvider backupProvider;

  const ProgressIndicatorCard({
    super.key,
    required this.backupProvider,
  });

  @override
  Widget build(BuildContext context) {
    final event = backupProvider.currentUploadEvent;
    final isScanning = backupProvider.isScanning;
    final scanProgress = backupProvider.scanProgress;

    if (!isScanning && event == null && !backupProvider.isSyncing) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    if (isScanning && scanProgress != null) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Indexing Device Media...',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(scanProgress.progress * 100).toInt()}%',
                    style: const TextStyle(
                      color: AppTheme.primaryAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: scanProgress.progress,
                backgroundColor: Colors.white12,
                color: AppTheme.primaryAccent,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                scanProgress.currentBatchStatus,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    if (event != null) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    event.item.mediaType.name == 'video'
                        ? Icons.videocam
                        : Icons.image,
                    color: AppTheme.primaryAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      event.item.fileName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(event.progress * 100).toInt()}%',
                    style: const TextStyle(
                      color: AppTheme.primaryAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: event.progress,
                backgroundColor: Colors.white12,
                color: AppTheme.emeraldGreen,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    event.statusMessage,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
                  ),
                  Text(
                    '${(event.bytesSent / (1024 * 1024)).toStringAsFixed(1)} / ${(event.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
