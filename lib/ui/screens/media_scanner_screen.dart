import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/backup_provider.dart';
import '../widgets/permission_banner.dart';
import '../widgets/stat_card.dart';

class MediaScannerScreen extends StatelessWidget {
  const MediaScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backup = context.watch<BackupProvider>();
    final stats = backup.stats;
    final scanProgress = backup.scanProgress;
    final df = DateFormat('MMM dd, yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Media Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: backup.isScanning ? null : () => backup.refreshData(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PermissionBanner(
                isPartialAccess: backup.isPartialAccess,
                onManagePermissions: () =>
                    Navigator.pushNamed(context, '/permissions'),
              ),

              // Scan Action Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.darkCardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.perm_media_outlined,
                            color: AppTheme.primaryAccent,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Local Library Indexer',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                backup.lastScanTime != null
                                    ? 'Last scan: ${df.format(backup.lastScanTime!)}'
                                    : 'No scans recorded yet',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Discovers all accessible photos and videos across your camera roll, screenshots, downloads, and custom albums without loading full-resolution media into memory.',
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 20),

                    if (backup.isScanning && scanProgress != null) ...[
                      LinearProgressIndicator(
                        value: scanProgress.progress,
                        color: AppTheme.primaryAccent,
                        backgroundColor: Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              scanProgress.currentBatchStatus,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${(scanProgress.progress * 100).toInt()}%',
                            style: const TextStyle(
                              color: AppTheme.primaryAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: backup.isScanning
                                ? null
                                : () => backup.startScan(forceFullScan: false),
                            icon: backup.isScanning
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.sync),
                            label: Text(
                              backup.isScanning ? 'Scanning...' : 'Incremental Scan',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: backup.isScanning
                              ? null
                              : () => backup.startScan(forceFullScan: true),
                          child: const Text('Full Rescan'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Discovery Metrics',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Photos',
                        value: stats.totalAccessiblePhotos.toString(),
                        icon: Icons.photo,
                        iconColor: AppTheme.primaryAccent,
                        subtitle: 'Discovered images',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'Videos',
                        value: stats.totalAccessibleVideos.toString(),
                        icon: Icons.videocam,
                        iconColor: AppTheme.indigoPurple,
                        subtitle: 'Discovered videos',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Total Size',
                        value: stats.formattedTotalMediaSize,
                        icon: Icons.data_usage,
                        iconColor: AppTheme.emeraldGreen,
                        subtitle: 'Local storage',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'Total Items',
                        value: stats.totalAccessibleMedia.toString(),
                        icon: Icons.collections,
                        iconColor: AppTheme.amberWarning,
                        subtitle: 'Accessible files',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
