import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/backup_provider.dart';
import '../../providers/settings_provider.dart';

class PrivacyAccountScreen extends StatelessWidget {
  const PrivacyAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final backup = context.watch<BackupProvider>();
    final settingsProv = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Account'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Account Card
            Container(
              padding: const EdgeInsets.all(16),
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
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: auth.isAuthenticated
                            ? AppTheme.primaryBlue.withOpacity(0.2)
                            : Colors.white10,
                        child: Icon(
                          auth.isAuthenticated
                              ? Icons.verified_user
                              : Icons.account_circle_outlined,
                          color: auth.isAuthenticated
                              ? AppTheme.primaryAccent
                              : Colors.white54,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.isAuthenticated
                                  ? (auth.userDisplayName ?? 'Google User')
                                  : 'No Account Connected',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              auth.isAuthenticated
                                  ? (auth.userEmail ?? '')
                                  : 'Connect Google account to enable Drive backups',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (auth.isAuthenticated) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.roseDanger,
                          side: const BorderSide(color: AppTheme.roseDanger),
                        ),
                        onPressed: () => _confirmDisconnect(context, auth),
                        icon: const Icon(Icons.link_off),
                        label: const Text('Disconnect & Revoke OAuth Access'),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/drive-connect'),
                        icon: const Icon(Icons.login),
                        label: const Text('Connect Google Drive'),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Consent Management Card
            _sectionHeader(theme, 'Data & Consent Controls'),
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
                  ListTile(
                    title: const Text('Revoke Automatic Backup Consent'),
                    subtitle: const Text(
                      'Immediately halts all automatic uploads and scanning operations.',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                    trailing: const Icon(Icons.cancel_outlined, color: AppTheme.roseDanger),
                    onTap: () {
                      settingsProv.setConsent(false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Backup consent revoked')),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Reset Local Database & Manifest'),
                    subtitle: const Text(
                      'Clears local index and metadata cache. Never touches device photos or Drive files.',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                    trailing: const Icon(Icons.delete_sweep_outlined, color: AppTheme.amberWarning),
                    onTap: () => _confirmResetManifest(context, backup),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Security Guarantees Card
            _sectionHeader(theme, 'Security Architecture'),
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
                    'Direct-to-Drive Security Model',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 10),
                  SecurityBullet(
                    'No Custom Backend',
                    'Media bytes travel directly from your Flutter mobile client to Google Drive API endpoints over TLS 1.3.',
                  ),
                  SecurityBullet(
                    'Narrowest Scope',
                    'Uses drive.file scope. The app can only see and manage folders and files it created itself.',
                  ),
                  SecurityBullet(
                    'Zero Credentials Stored in Plaintext',
                    'Tokens are cached in hardware platform-secure storage (Keychain / EncryptedSharedPreferences).',
                  ),
                  SecurityBullet(
                    'Zero Phone File Modifications',
                    'The application only reads local media bytes. It has no deletion or write permissions over your original phone photos or videos.',
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

  void _confirmDisconnect(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.darkCard,
          title: const Text('Disconnect Account?'),
          content: const Text(
            'This will sign you out and revoke active OAuth tokens. Automatic backups will be paused until you re-authenticate.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.roseDanger),
              onPressed: () {
                auth.disconnect();
                Navigator.pop(context);
              },
              child: const Text('Disconnect'),
            ),
          ],
        );
      },
    );
  }

  void _confirmResetManifest(BuildContext context, BackupProvider backup) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.darkCard,
          title: const Text('Reset Local Database?'),
          content: const Text(
            'This will clear the local SQLite manifest table. Next time you scan, media files will be re-indexed. Google Drive files will NOT be affected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.amberWarning),
              onPressed: () {
                backup.resetAllData();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Local manifest cleared')),
                );
              },
              child: const Text('Reset Manifest'),
            ),
          ],
        );
      },
    );
  }
}

class SecurityBullet extends StatelessWidget {
  final String title;
  final String description;

  const SecurityBullet(this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 16, color: AppTheme.emeraldGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
