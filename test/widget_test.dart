import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scanner/main.dart';
import 'package:scanner/providers/auth_provider.dart';
import 'package:scanner/providers/backup_provider.dart';
import 'package:scanner/providers/settings_provider.dart';

void main() {
  testWidgets('App smoke test loads Media Library dashboard',
      (WidgetTester tester) async {
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

    await tester.pump();

    // Verify Gallery screen loads
    expect(find.text('Gallery'), findsOneWidget);
  });
}
