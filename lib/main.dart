import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/backup_provider.dart';
import 'providers/settings_provider.dart';
import 'services/background_sync_manager.dart';
import 'services/favorites_service.dart';
import 'ui/screens/media_library_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize persistent background sync service (survives reboot, runs continuously)
  try {
    await BackgroundSyncManager.instance.initialize();
  } catch (e) {
    debugPrint('Background service init warning: $e');
  }

  // Dark navigation bar and status bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
        ChangeNotifierProvider(create: (_) => BackupProvider()..init()),
        ChangeNotifierProvider.value(value: FavoritesService.instance..init()),
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
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const MediaLibraryScreen(),
    );
  }
}
