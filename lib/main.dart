import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/backup_provider.dart';
import 'providers/settings_provider.dart';
import 'ui/screens/drive_connect_screen.dart';
import 'ui/screens/history_and_failures_screen.dart';
import 'ui/screens/main_navigation_screen.dart';
import 'ui/screens/media_scanner_screen.dart';
import 'ui/screens/privacy_account_screen.dart';
import 'ui/screens/upload_queue_screen.dart';
import 'ui/screens/welcome_permissions_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dark navigation bar and status bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.darkCard,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
        ChangeNotifierProvider(create: (_) => BackupProvider()..init()),
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
      title: 'Media Drive Backup',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      initialRoute: '/',
      routes: {
        '/': (context) => const MainNavigationScreen(),
        '/permissions': (context) => const WelcomePermissionsScreen(),
        '/drive-connect': (context) => const DriveConnectScreen(),
        '/scanner': (context) => const MediaScannerScreen(),
        '/history': (context) => const HistoryAndFailuresScreen(),
        '/privacy': (context) => const PrivacyAccountScreen(),
        '/queue': (context) => const UploadQueueScreen(),
      },
    );
  }
}
