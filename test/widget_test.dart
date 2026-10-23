import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scanner/main.dart';
import 'package:scanner/providers/auth_provider.dart';
import 'package:scanner/providers/backup_provider.dart';
import 'package:scanner/providers/settings_provider.dart';

void main() {
  testWidgets('App smoke test loads navigation bar', (WidgetTester tester) async {
    // Provide providers without running platform-specific native calls
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => BackupProvider()),
        ],
        child: const MediaBackupApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify main destinations exist
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Library'), findsWidgets);
    expect(find.text('Analysis'), findsWidgets);
    expect(find.text('Queue'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}
