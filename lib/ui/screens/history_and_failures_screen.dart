import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../providers/backup_provider.dart';
import '../../providers/settings_provider.dart';

class HistoryAndFailuresScreen extends StatelessWidget {
  const HistoryAndFailuresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('History & Failures'),
          bottom: const TabBar(
            indicatorColor: AppTheme.primaryAccent,
            labelColor: AppTheme.primaryAccent,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(icon: Icon(Icons.check_circle_outline), text: 'Uploaded'),
              Tab(icon: Icon(Icons.error_outline), text: 'Failed'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _UploadedHistoryTab(),
            _FailedUploadsTab(),
          ],
        ),
      ),
    );
  }
}

class _UploadedHistoryTab extends StatelessWidget {
  const _UploadedHistoryTab();

  @override
  Widget build(BuildContext context) {
    final backup = context.watch<BackupProvider>();
    final uploads = backup.recentUploads;
    final df = DateFormat('MMM dd, yyyy HH:mm');

    if (uploads.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text(
              'No Successful Uploads Yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Files uploaded to Google Drive will be cataloged here.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: uploads.length,
      itemBuilder: (context, index) {
        final item = uploads[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.darkCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    item.mediaType == AppMediaType.video
                        ? Icons.videocam
                        : Icons.image,
                    color: AppTheme.emeraldGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.fileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    item.formattedSize,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (item.driveFileId != null) ...[
                Text(
                  'Drive ID: ${item.driveFileId}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: AppTheme.primaryAccent,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                'Destination: ${item.computeTargetFolderPath()}',
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Uploaded at: ${item.uploadedAt != null ? df.format(item.uploadedAt!) : "N/A"}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FailedUploadsTab extends StatelessWidget {
  const _FailedUploadsTab();

  @override
  Widget build(BuildContext context) {
    final backup = context.watch<BackupProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    final failed = backup.failedItems;

    if (failed.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 64, color: AppTheme.emeraldGreen),
            SizedBox(height: 16),
            Text(
              'No Failed Uploads',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'All scheduled media transfers completed smoothly.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppTheme.roseDanger.withOpacity(0.12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${failed.length} items failed to upload',
                style: const TextStyle(
                  color: AppTheme.roseDanger,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.roseDanger,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                ),
                onPressed: () => backup.retryFailedUploads(settings),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry All'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: failed.length,
            itemBuilder: (context, index) {
              final item = failed[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.roseDanger.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppTheme.roseDanger,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.fileName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'Retries: ${item.retryCount}',
                          style: const TextStyle(
                            color: AppTheme.amberWarning,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.errorMessage ?? 'Unknown network or API error',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.formattedSize,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                          ),
                        ),
                        TextButton(
                          onPressed: () => backup.retryFailedUploads(settings),
                          child: const Text('Retry File'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
