import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/backup_provider.dart';
import '../../providers/settings_provider.dart';

/// Opens the 3D Cloud Backup Quick Hub bottom sheet
void showThreeDCloudHubSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const ThreeDCloudHubSheet(),
  );
}

class ThreeDCloudHubSheet extends StatelessWidget {
  const ThreeDCloudHubSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final backup = context.watch<BackupProvider>();
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();

    final stats = backup.stats;
    final total = stats.totalAccessibleMedia;
    final uploaded = stats.uploadedFiles;
    final pending = stats.pendingUploads;
    final failed = stats.failedUploads;
    final percent = total > 0 ? (uploaded / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C1322),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: 1.2,
        ),
        boxShadow: AppTheme.depthShadow(
          depth: 20,
          glowColor: AppTheme.primaryAccent,
          glowOpacity: 0.15,
        ),
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header: Cloud Sync Title + Account State
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryAccent, AppTheme.primaryBlue],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryAccent.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.cloud_sync_rounded,
                  color: Colors.black,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Google Drive Backup',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      auth.isAuthenticated
                          ? (auth.userEmail ?? 'Connected to Google Drive')
                          : 'Not connected to Google Drive',
                      style: TextStyle(
                        fontSize: 12,
                        color: auth.isAuthenticated
                            ? AppTheme.emeraldGreen
                            : Colors.white54,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!auth.isAuthenticated)
                ElevatedButton(
                  onPressed: () => auth.signIn(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // 3D Progress Pill Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
              boxShadow: AppTheme.depthShadow(depth: 8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      backup.isSyncing
                          ? 'Backing up media...'
                          : (percent >= 1.0 && total > 0
                              ? 'All media backed up'
                              : 'Backup Status'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      '${(percent * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 7,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatPill('Total', '$total', Colors.white),
                    _buildStatPill('Backed Up', '$uploaded', AppTheme.emeraldGreen),
                    _buildStatPill('Pending', '$pending', AppTheme.neonAzure),
                    if (failed > 0)
                      _buildStatPill('Failed', '$failed', AppTheme.roseDanger),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons: Manual Sync Now & Settings Toggles
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (backup.isSyncing) {
                      backup.pauseBackup();
                    } else {
                      backup.startBackup(settings.settings, isManual: true);
                    }
                  },
                  icon: Icon(
                    backup.isSyncing
                        ? Icons.pause_circle_outline
                        : Icons.cloud_upload_outlined,
                    size: 18,
                  ),
                  label: Text(backup.isSyncing ? 'Pause Sync' : 'Sync Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: backup.isSyncing
                        ? AppTheme.amberWarning
                        : AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () {
                  backup.startScan(forceFullScan: true);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Re-scan'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Quick Backup Options
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.darkCard.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.06),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildQuickToggle(
                  label: 'Wi-Fi Only',
                  icon: Icons.wifi,
                  value: settings.settings.wifiOnly,
                  onChanged: (val) => settings.toggleWifiOnly(val),
                ),
                Container(width: 1, height: 28, color: Colors.white10),
                _buildQuickToggle(
                  label: 'Auto Backup',
                  icon: Icons.sync,
                  value: settings.settings.autoBackupEnabled,
                  onChanged: (val) => settings.toggleAutoBackup(val),
                ),
                Container(width: 1, height: 28, color: Colors.white10),
                _buildQuickToggle(
                  label: 'Charging Only',
                  icon: Icons.battery_charging_full_rounded,
                  value: settings.settings.chargingOnly,
                  onChanged: (val) => settings.toggleChargingOnly(val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String title, String count, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white38,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickToggle({
    required String label,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          children: [
            Icon(
              icon,
              size: 18,
              color: value ? AppTheme.primaryAccent : Colors.white24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: value ? Colors.white : Colors.white38,
                fontWeight: value ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
