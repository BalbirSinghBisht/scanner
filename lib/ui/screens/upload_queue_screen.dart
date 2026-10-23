import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../providers/backup_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/progress_indicator_card.dart';

class UploadQueueScreen extends StatelessWidget {
  const UploadQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backup = context.watch<BackupProvider>();
    final settings = context.watch<SettingsProvider>().settings;

    // Filter pending/uploading/retry-pending items
    final queueItems = backup.mediaItems
        .where((item) =>
            item.uploadState == UploadState.READY_TO_UPLOAD ||
            item.uploadState == UploadState.RETRY_PENDING ||
            item.uploadState == UploadState.UPLOADING)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Queue'),
        actions: [
          if (backup.isSyncing)
            IconButton(
              icon: Icon(backup.isPaused ? Icons.play_arrow : Icons.pause),
              onPressed: () {
                if (backup.isPaused) {
                  backup.resumeBackup(settings);
                } else {
                  backup.pauseBackup();
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live active upload progress card
            ProgressIndicatorCard(backupProvider: backup),

            // Queue Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Queued Items (${queueItems.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (queueItems.isNotEmpty && !backup.isSyncing)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                      ),
                      onPressed: () => backup.startBackup(settings, isManual: true),
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('Process Queue'),
                    ),
                ],
              ),
            ),

            // List of items in queue
            Expanded(
              child: queueItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.done_all_rounded,
                            size: 64,
                            color: AppTheme.emeraldGreen.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Upload Queue is Empty',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'All eligible media files have been uploaded or no pending items.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: queueItems.length,
                      itemBuilder: (context, index) {
                        final item = queueItems[index];
                        final isCurrentlyUploading =
                            item.uploadState == UploadState.UPLOADING;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.darkCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isCurrentlyUploading
                                  ? AppTheme.primaryAccent
                                  : AppTheme.darkCardBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  item.mediaType == AppMediaType.video
                                      ? Icons.videocam
                                      : Icons.photo,
                                  color: isCurrentlyUploading
                                      ? AppTheme.primaryAccent
                                      : Colors.white70,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.fileName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Text(
                                          item.formattedSize,
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '• Target: ${item.computeTargetFolderPath()}',
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isCurrentlyUploading)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primaryAccent,
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: item.uploadState ==
                                            UploadState.RETRY_PENDING
                                        ? AppTheme.amberWarning.withOpacity(0.2)
                                        : AppTheme.primaryBlue.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    item.uploadState == UploadState.RETRY_PENDING
                                        ? 'Retry #${item.retryCount}'
                                        : 'Pending',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: item.uploadState ==
                                              UploadState.RETRY_PENDING
                                          ? AppTheme.amberWarning
                                          : AppTheme.primaryAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
