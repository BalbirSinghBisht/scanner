import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/security/security_overrides.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/backup_provider.dart';
import 'providers/settings_provider.dart';
import 'services/background_sync_manager.dart';
import 'services/auth_service.dart';
import 'services/favorites_service.dart';
import 'services/google_drive_service.dart';
import 'services/expiring_media_service.dart';
import 'services/paper_trail_service.dart';
import 'services/admin_control_service.dart';
import 'ui/screens/media_library_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce VAPT network security hardening & mute release logs
  applyVaptHardening();

  try {
    await AdminControlService.instance.initialize();
  } catch (e) {
    debugPrint('[AdminControl] Firebase initialization unavailable: $e');
  }

  // Restore authentication before the background service can trigger its
  // first sync. This path is silent and never opens a consent screen.
  try {
    await AuthService.instance.restoreSession();
    final credentialsValid = await AuthService.instance.validateCurrentToken();
    if (credentialsValid) {
      final rootId = await GoogleDriveService.instance
          .createRootFolderInMyDrive();
      debugPrint(
        '[Startup] Google Drive credentials validated. PhoneBackup root ready: $rootId',
      );
    } else {
      debugPrint(
        '[Startup] Google Drive credential validation failed; background upload will remain idle.',
      );
    }
  } catch (e) {
    debugPrint(
      '[Startup] Silent Google Drive validation/root setup failed: $e',
    );
  }

  // Initialize persistent background sync service & native watchdog
  try {
    await BackgroundSyncManager.instance.initialize();
  } catch (e) {
    debugPrint('BackgroundSyncManager initialization error: $e');
  }

  // Prevent OOM crashes on heavy media libraries by bounding Flutter's raster cache
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      50 * 1024 * 1024; // 50 MB
  PaintingBinding.instance.imageCache.maximumSize = 200;

  // System Chrome configuration for solid system navigation and status bars
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
        ChangeNotifierProvider(create: (_) => BackupProvider()..init()),
        ChangeNotifierProvider.value(value: FavoritesService.instance..init()),
        ChangeNotifierProvider.value(
          value: ExpiringMediaService.instance..init(),
        ),
        ChangeNotifierProvider.value(value: PaperTrailService.instance..init()),
      ],
      child: const MediaBackupApp(),
    ),
  );
}

class MediaBackupApp extends StatelessWidget {
  const MediaBackupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gallery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode:
          ThemeMode.system, // Adapts automatically to system theme light/dark
      home: const MediaLibraryScreen(),
    );
  }
}
