import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/backup_provider.dart';
import 'analysis_dashboard_screen.dart';
import 'backup_dashboard_screen.dart';
import 'backup_settings_screen.dart';
import 'media_library_screen.dart';
import 'upload_queue_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    BackupDashboardScreen(),
    MediaLibraryScreen(),
    AnalysisDashboardScreen(),
    UploadQueueScreen(),
    BackupSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final backup = context.watch<BackupProvider>();
    final auth = context.watch<AuthProvider>();
    final pendingCount = backup.stats.pendingUploads;

    return Scaffold(
      drawer: _buildAppDrawer(context, auth, backup),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: 'Library',
          ),
          const NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Analysis',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text('$pendingCount'),
              child: const Icon(Icons.cloud_upload_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text('$pendingCount'),
              child: const Icon(Icons.cloud_upload),
            ),
            label: 'Queue',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildAppDrawer(
    BuildContext context,
    AuthProvider auth,
    BackupProvider backup,
  ) {
    return Drawer(
      backgroundColor: AppTheme.darkBg,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: AppTheme.darkCard,
              border: Border(bottom: BorderSide(color: AppTheme.darkCardBorder)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.cloud_sync_rounded,
                        color: AppTheme.primaryAccent,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Drive Backup',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  auth.isAuthenticated
                      ? (auth.userEmail ?? 'Connected')
                      : 'Not connected to Google Drive',
                  style: TextStyle(
                    fontSize: 12,
                    color: auth.isAuthenticated
                        ? AppTheme.emeraldGreen
                        : Colors.white54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_to_drive, color: AppTheme.primaryAccent),
            title: const Text('Google Drive Account'),
            subtitle: Text(
              auth.isAuthenticated ? 'Connected' : 'Sign in required',
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/drive-connect');
            },
          ),
          ListTile(
            leading: const Icon(Icons.perm_media, color: AppTheme.indigoPurple),
            title: const Text('Media Scanner'),
            subtitle: const Text(
              'Incremental & full device scan',
              style: TextStyle(fontSize: 11, color: Colors.white54),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/scanner');
            },
          ),
          ListTile(
            leading: const Icon(Icons.history, color: AppTheme.emeraldGreen),
            title: const Text('Backup History & Failures'),
            subtitle: Text(
              '${backup.stats.uploadedFiles} uploaded • ${backup.stats.failedUploads} failed',
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/history');
            },
          ),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined, color: AppTheme.amberWarning),
            title: const Text('Permissions & Privacy'),
            subtitle: const Text(
              'Media access & consent management',
              style: TextStyle(fontSize: 11, color: Colors.white54),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/permissions');
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: Colors.white70),
            title: const Text('Security & Data Controls'),
            subtitle: const Text(
              'Manifest reset & OAuth revocation',
              style: TextStyle(fontSize: 11, color: Colors.white54),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/privacy');
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Media Drive Backup v1.0.0\nDirect-to-Drive • Zero Server Backend',
              style: TextStyle(fontSize: 11, color: Colors.white30, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
