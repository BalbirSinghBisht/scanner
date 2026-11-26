import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

const adminEmail = 'balbirbisht372@gmail.com';
const driveOAuthClientId = String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Gallery Admin',
    debugShowCheckedModeBanner: false,
    themeMode: ThemeMode.system,
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    home: const AuthGate(),
  );

  ThemeData _theme(Brightness brightness) => ThemeData(
    brightness: brightness,
    colorSchemeSeed: const Color(0xFF007AFF),
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? Colors.black
        : const Color(0xFFF2F2F7),
    useMaterial3: true,
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}

class DeviceRecord {
  final String id, name, syncState;
  final DateTime? lastSeen;
  final int pendingFiles;
  const DeviceRecord({
    required this.id,
    required this.name,
    required this.syncState,
    this.lastSeen,
    this.pendingFiles = 0,
  });
  bool get isOnline =>
      lastSeen != null && DateTime.now().difference(lastSeen!).inMinutes < 20;
  factory DeviceRecord.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return DeviceRecord(
      id: doc.id,
      name: data['name']?.toString() ?? 'Unknown device',
      syncState: data['syncState']?.toString() ?? 'idle',
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
      pendingFiles: (data['pendingFiles'] as num?)?.toInt() ?? 0,
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (_, snapshot) => snapshot.data == null
        ? const AdminLoginScreen()
        : const AdminDashboard(),
  );
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: adminEmail,
        password: _password.text,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Unable to sign in');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.admin_panel_settings,
                  size: 56,
                  color: Color(0xFF007AFF),
                ),
                const SizedBox(height: 16),
                Text(
                  'Gallery Admin',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(adminEmail),
                const SizedBox(height: 18),
                TextField(
                  controller: _password,
                  obscureText: true,
                  onSubmitted: (_) => _signIn(),
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _signIn,
                    child: Text(_busy ? 'Signing in…' : 'Sign in'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: driveOAuthClientId.isEmpty ? null : driveOAuthClientId,
    scopes: const [drive.DriveApi.driveReadonlyScope],
  );
  String _driveValue = 'Connect';
  bool _driveLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDrive(interactive: false);
  }

  Future<void> _loadDrive({required bool interactive}) async {
    if (_driveLoading) return;
    setState(() => _driveLoading = true);
    try {
      final account = interactive
          ? await _googleSignIn.signIn()
          : await _googleSignIn.signInSilently();
      if (account == null) {
        if (mounted) setState(() => _driveValue = 'Connect');
        return;
      }
      if (account.email.toLowerCase() != adminEmail.toLowerCase()) {
        await _googleSignIn.signOut();
        throw StateError('Use the shared Drive account: $adminEmail');
      }
      final client = await _googleSignIn.authenticatedClient();
      if (client == null) throw StateError('Google Drive authorization failed');
      final api = drive.DriveApi(client);
      var count = 0;
      String? pageToken;
      do {
        final page = await api.files.list(
          q: 'trashed = false',
          spaces: 'drive',
          pageSize: 1000,
          pageToken: pageToken,
          $fields: 'nextPageToken,files(id)',
        );
        count += page.files?.length ?? 0;
        pageToken = page.nextPageToken;
      } while (pageToken != null && pageToken.isNotEmpty);
      if (mounted) setState(() => _driveValue = '$count files');
    } catch (e) {
      if (mounted) {
        setState(() => _driveValue = 'Connect');
        if (interactive) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Drive connection failed: $e')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _driveLoading = false);
    }
  }

  Future<void> _startSync(BuildContext context, DeviceRecord device) async {
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('devices').doc(device.id).update({
      'pendingCommand': 'startSync',
      'commandAt': FieldValue.serverTimestamp(),
    });
    await firestore.collection('auditLog').add({
      'adminEmail': adminEmail,
      'deviceId': device.id,
      'command': 'startSync',
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sync queued for ${device.name}')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Gallery Admin'),
      actions: [
        IconButton(
          onPressed: FirebaseAuth.instance.signOut,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('devices')
          .orderBy('lastSeen', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Unable to load devices: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final devices = snapshot.data!.docs.map(DeviceRecord.fromDoc).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _metric('Devices', '${devices.length}', Icons.devices),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metric(
                    'Drive',
                    _driveLoading ? 'Loading…' : _driveValue,
                    Icons.cloud_outlined,
                    onTap: () => _loadDrive(interactive: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              'Connected devices',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (devices.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No registered devices yet.'),
                ),
              ),
            ...devices.map(
              (device) => Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: device.isOnline
                        ? Colors.green
                        : Colors.grey,
                    child: const Icon(Icons.phone_android, color: Colors.white),
                  ),
                  title: Text(
                    device.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${device.syncState} • ${device.pendingFiles} pending',
                  ),
                  trailing: FilledButton.icon(
                    onPressed: () => _startSync(context, device),
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Start'),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _metric(
    String label,
    String value,
    IconData icon, {
    VoidCallback? onTap,
  }) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF007AFF)),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(label),
          ],
        ),
      ),
    ),
  );
}
