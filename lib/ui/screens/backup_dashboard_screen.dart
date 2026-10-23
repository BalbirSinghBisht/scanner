import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/backup_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/permission_banner.dart';
import '../widgets/progress_indicator_card.dart';
import '../widgets/stat_card.dart';

class BackupDashboardScreen extends StatelessWidget {
  const BackupDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backup = context.watch<BackupProvider>();
    final auth = context.watch<AuthProvider>();
    final settingsProv = context.watch<SettingsProvider>();
    final settings = settingsProv.settings;
    final stats = backup.stats;
    final df = DateFormat('MMM dd, yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => backup.refreshData(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => backup.refreshData(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selected media warning banner
                PermissionBanner(
                  isPartialAccess: backup.isPartialAccess,
                  onManagePermissions: () =>
                      Navigator.pushNamed(context, '/permissions'),
                ),

                // Live Upload or Scan Progress Card
                ProgressIndicatorCard(backupProvider: backup),

                // Main Completion & Status Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.darkCardBorder),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryBlue.withOpacity(0.15),
                        AppTheme.darkCard,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stats.currentUploadStatus,
                                style: const TextStyle(
                                  color: AppTheme.primaryAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                auth.isAuthenticated
                                    ? (auth.userEmail ?? 'Connected')
                                    : 'Drive Account Not Connected',
                                style: TextStyle(
                                  color: auth.isAuthenticated
                                      ? Colors.white70
                                      : AppTheme.amberWarning,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${stats.backupCompletionPercentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppTheme.primaryAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Progress Bar
                      LinearProgressIndicator(
                        value: stats.backupCompletionPercentage / 100,
                        backgroundColor: Colors.white12,
                        color: AppTheme.primaryAccent,
                        borderRadius: BorderRadius.circular(6),
                        minHeight: 8,
                      ),
                      const SizedBox(height: 16),

                      // Timing Info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            stats.lastSuccessfulBackupTime != null
                                ? 'Last success: ${df.format(stats.lastSuccessfulBackupTime!)}'
                                : 'No completed backups yet',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '${stats.uploadedFiles} / ${stats.totalAccessibleMedia} backed up',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Quick Action Buttons
                      Row(
                        children: [
                          if (backup.isSyncing) ...[
                            Expanded(
                              child: backup.isPaused
                                  ? ElevatedButton.icon(
                                      onPressed: () => backup.resumeBackup(settings),
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text('Resume Backup'),
                                    )
                                  : ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.amberWarning,
                                      ),
                                      onPressed: () => backup.pauseBackup(),
                                      icon: const Icon(Icons.pause),
                                      label: const Text('Pause Backup'),
                                    ),
                            ),
                          ] else ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: !auth.isAuthenticated && !settings.localOnlyMode
                                    ? () => Navigator.pushNamed(context, '/drive-connect')
                                    : () => backup.startBackup(settings, isManual: true),
                                icon: const Icon(Icons.cloud_upload_outlined),
                                label: Text(
                                  !auth.isAuthenticated && !settings.localOnlyMode
                                      ? 'Connect Drive to Backup'
                                      : 'Start Backup',
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 10),
                          IconButton.filledTonal(
                            onPressed: () => backup.startScan(),
                            icon: const Icon(Icons.sync),
                            tooltip: 'Scan Library',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Storage & File Metrics',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Metrics Grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: 'Uploaded',
                          value: stats.uploadedFiles.toString(),
                          icon: Icons.cloud_done_rounded,
                          iconColor: AppTheme.emeraldGreen,
                          subtitle: stats.formattedCloudStorage,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'Pending',
                          value: stats.pendingUploads.toString(),
                          icon: Icons.hourglass_top_rounded,
                          iconColor: AppTheme.primaryAccent,
                          subtitle: 'Ready in queue',
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
                          title: 'Failed',
                          value: stats.failedUploads.toString(),
                          icon: Icons.error_outline_rounded,
                          iconColor: AppTheme.roseDanger,
                          subtitle: 'Retry available',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'Skipped',
                          value: stats.skippedFiles.toString(),
                          icon: Icons.skip_next_rounded,
                          iconColor: AppTheme.amberWarning,
                          subtitle: 'Exceeds limits',
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
                          title: 'Total Photos',
                          value: stats.totalAccessiblePhotos.toString(),
                          icon: Icons.photo,
                          iconColor: AppTheme.primaryAccent,
                          subtitle: 'Accessible images',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'Total Videos',
                          value: stats.totalAccessibleVideos.toString(),
                          icon: Icons.videocam,
                          iconColor: AppTheme.indigoPurple,
                          subtitle: 'Accessible videos',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Retry Failed Banner if failures exist
                if (stats.failedUploads > 0) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.roseDanger.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.roseDanger.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppTheme.roseDanger, size: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${stats.failedUploads} Failed Uploads',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.roseDanger,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Some uploads encountered network or timeout errors.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.roseDanger,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () => backup.retryFailedUploads(settings),
                          child: const Text('Retry All'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Recent Upload Activity
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Upload Activity',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/queue'),
                        child: const Text('View All Queue →'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                if (backup.recentUploads.isEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.darkCardBorder),
                    ),
                    child: const Center(
                      child: Text(
                        'No uploaded files yet. Connect Google Drive and start backup.',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: backup.recentUploads.take(5).length,
                    itemBuilder: (context, idx) {
                      final item = backup.recentUploads[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.darkCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.darkCardBorder),
                        ),
                        child: ListTile(
                          leading: Icon(
                            item.mediaType == AppMediaType.video
                                ? Icons.videocam
                                : Icons.image,
                            color: AppTheme.emeraldGreen,
                          ),
                          title: Text(
                            item.fileName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${item.formattedSize} • ${item.uploadedAt != null ? df.format(item.uploadedAt!) : ''}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.check_circle,
                            color: AppTheme.emeraldGreen,
                            size: 18,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
