import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/settings_provider.dart';

class BackupSettingsScreen extends StatelessWidget {
  const BackupSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProv = context.watch<SettingsProvider>();
    final settings = settingsProv.settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Consent & Auto-Backup Section
            _sectionHeader(theme, 'Automatic Backup & Consent'),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.darkCardBorder),
              ),
              color: AppTheme.darkCard,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text(
                      'User Explicit Consent',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'I authorize this app to scan device media and upload to my Google Drive.',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                    value: settings.userConsentGiven,
                    activeColor: AppTheme.emeraldGreen,
                    onChanged: (val) {
                      if (val) {
                        _showConsentDialog(context, settingsProv);
                      } else {
                        settingsProv.setConsent(false);
                      }
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text(
                      'Enable Automatic Backup',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Automatically upload new and pending media when conditions are met.',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                    value: settings.autoBackupEnabled,
                    activeColor: AppTheme.primaryAccent,
                    onChanged: settings.userConsentGiven
                        ? (val) => settingsProv.toggleAutoBackup(val)
                        : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Network Constraints Section
            _sectionHeader(theme, 'Network Settings'),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.darkCardBorder),
              ),
              color: AppTheme.darkCard,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Back up over Wi-Fi only'),
                    subtitle: Text(
                      settings.wifiOnly
                          ? 'Media is only uploaded when connected to Wi-Fi'
                          : 'Mobile cellular data is permitted for uploads',
                      style: const TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                    value: settings.wifiOnly,
                    activeColor: AppTheme.primaryAccent,
                    onChanged: (val) => settingsProv.toggleWifiOnly(val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Media Types Section
            _sectionHeader(theme, 'Media Inclusion'),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.darkCardBorder),
              ),
              color: AppTheme.darkCard,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Back up Photos & Images'),
                    subtitle: const Text(
                      'JPEG, PNG, HEIC, WebP, GIFs and screenshots',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                    value: settings.backupPhotos,
                    activeColor: AppTheme.primaryAccent,
                    onChanged: (val) => settingsProv.togglePhotos(val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Back up Videos'),
                    subtitle: const Text(
                      'MP4, MOV, and screen recordings',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                    value: settings.backupVideos,
                    activeColor: AppTheme.primaryAccent,
                    onChanged: (val) => settingsProv.toggleVideos(val),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Maximum Video Size Limit'),
                    subtitle: Text(
                      settings.maxVideoSizeBytes == null
                          ? 'No size limit (upload all videos)'
                          : 'Max ${(settings.maxVideoSizeBytes! / (1024 * 1024)).toStringAsFixed(0)} MB',
                      style: const TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showVideoSizePicker(context, settingsProv),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Power & Battery Constraints
            _sectionHeader(theme, 'Power & Battery Protection'),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.darkCardBorder),
              ),
              color: AppTheme.darkCard,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Require Charging'),
                      subtitle: const Text(
                        'Only upload when the device is plugged into a power source',
                        style: TextStyle(fontSize: 12, color: Colors.white60),
                      ),
                      value: settings.chargingOnly,
                      activeColor: AppTheme.emeraldGreen,
                      onChanged: (val) => settingsProv.toggleChargingOnly(val),
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Minimum Battery Threshold',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${settings.minBatteryThreshold}%',
                          style: const TextStyle(
                            color: AppTheme.primaryAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Slider(
                      value: settings.minBatteryThreshold.toDouble(),
                      min: 5,
                      max: 50,
                      divisions: 9,
                      activeColor: AppTheme.primaryAccent,
                      label: '${settings.minBatteryThreshold}%',
                      onChanged: (val) =>
                          settingsProv.setBatteryThreshold(val.toInt()),
                    ),
                    const Text(
                      'Backup will automatically pause if battery drops below this level while discharging.',
                      style: TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Testing / Local-Only Mode
            _sectionHeader(theme, 'Testing & Development Mode'),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.darkCardBorder),
              ),
              color: AppTheme.darkCard,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Local-Only Mode (Offline Test)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Enables full scanning, hashing, and queue management without transmitting bytes to Google Drive.',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                    value: settings.localOnlyMode,
                    activeColor: AppTheme.amberWarning,
                    onChanged: (val) => settingsProv.toggleLocalOnlyMode(val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Operating System Background Limitations Card
            _sectionHeader(theme, 'Platform Background Constraints'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OS Background Policy Note',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '• Android: Subject to Doze mode and manufacturer power management. WorkManager executes tasks when device conditions (network, battery) are met.\n'
                    '• iOS: Background URLSession or BGProcessingTasks operate at the discretion of iOS scheduling based on device usage patterns.\n'
                    '• Force-Stop: Modern mobile operating systems prohibit background transfers while the app is explicitly force-stopped by the user.',
                    style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: AppTheme.primaryAccent,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showConsentDialog(BuildContext context, SettingsProvider settingsProv) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.darkCard,
          title: const Text('User Explicit Consent'),
          content: const Text(
            'By enabling backup, you give this application permission to:\n\n'
            '1. Scan and read photos and videos in your device storage.\n'
            '2. Compute local file hashes (SHA-256) for duplicate prevention.\n'
            '3. Upload authorized media directly to your private Google Drive in the PhoneBackup folder.\n\n'
            'This application does not transmit your media to any third-party servers. Your original media on your phone is NEVER deleted.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                settingsProv.setConsent(true);
                Navigator.pop(context);
              },
              child: const Text('I Agree & Give Consent'),
            ),
          ],
        );
      },
    );
  }

  void _showVideoSizePicker(BuildContext context, SettingsProvider prov) {
    final options = <String, int?>{
      'No limit (Unlimited)': null,
      '50 MB max': 50 * 1024 * 1024,
      '100 MB max': 100 * 1024 * 1024,
      '250 MB max': 250 * 1024 * 1024,
      '500 MB max': 500 * 1024 * 1024,
      '1 GB max': 1024 * 1024 * 1024,
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Maximum Video Size',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ...options.entries.map((e) {
                final isSelected = prov.settings.maxVideoSizeBytes == e.value;
                return ListTile(
                  title: Text(e.key),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppTheme.primaryAccent)
                      : null,
                  onTap: () {
                    prov.setMaxVideoSize(e.value);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
