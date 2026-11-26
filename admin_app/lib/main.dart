import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

const adminEmail = 'balbirbisht372@gmail.com';

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
  final String id, name, syncState, driveFolderName;
  final DateTime? lastSeen;
  final int pendingFiles;
  const DeviceRecord({
    required this.id,
    required this.name,
    required this.syncState,
    required this.driveFolderName,
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
      driveFolderName:
          data['driveFolderName']?.toString() ??
          data['name']?.toString() ??
          'Phone_Device',
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

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

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

  Future<void> _editSyncPolicy(BuildContext context) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('config')
        .doc('syncPolicy')
        .get();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => SyncPolicyDialog(initial: snapshot.data()),
    );
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
        final driveFolders = devices
            .map((device) => device.driveFolderName)
            .toSet()
            .length;
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
                    'Drive folders',
                    '$driveFolders',
                    Icons.cloud_done_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('config')
                  .doc('syncPolicy')
                  .snapshots(),
              builder: (context, policySnapshot) {
                final data = policySnapshot.data?.data();
                final label = data?['mode'] == 'range'
                    ? '${_dateLabel(data?['rangeStart'])} – ${_dateLabel(data?['rangeEnd'])}'
                    : '${data?['amount'] ?? 10} ${data?['unit'] ?? 'days'}';
                return Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.date_range,
                      color: Color(0xFF007AFF),
                    ),
                    title: const Text('Sync threshold'),
                    subtitle: Text(label),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _editSyncPolicy(context),
                  ),
                );
              },
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
                    '${device.syncState} • ${device.pendingFiles} pending\n'
                    'Drive: PhoneBackup/${device.driveFolderName}',
                  ),
                  isThreeLine: true,
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

  Widget _metric(String label, String value, IconData icon) => Card(
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
  );

  String _dateLabel(dynamic value) {
    final date = value is Timestamp ? value.toDate() : null;
    return date == null
        ? 'Not set'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class SyncPolicyDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const SyncPolicyDialog({super.key, this.initial});
  @override
  State<SyncPolicyDialog> createState() => _SyncPolicyDialogState();
}

class _SyncPolicyDialogState extends State<SyncPolicyDialog> {
  late String _mode;
  late String _unit;
  late final TextEditingController _amount;
  DateTime? _start;
  DateTime? _end;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.initial;
    _mode = data?['mode']?.toString() ?? 'rolling';
    _unit = data?['unit']?.toString() ?? 'days';
    _amount = TextEditingController(text: '${data?['amount'] ?? 10}');
    _start = (data?['rangeStart'] as Timestamp?)?.toDate();
    _end = (data?['rangeEnd'] as Timestamp?)?.toDate();
  }

  Future<void> _pick(bool start) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDate: (start ? _start : _end) ?? DateTime.now(),
    );
    if (selected != null) {
      setState(() => start ? _start = selected : _end = selected);
    }
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amount.text);
    if (_mode == 'rolling' && (amount == null || amount < 1)) return;
    if (_mode == 'range' &&
        (_start == null || _end == null || _start!.isAfter(_end!))) {
      return;
    }
    setState(() => _saving = true);
    await FirebaseFirestore.instance.collection('config').doc('syncPolicy').set(
      {
        'mode': _mode,
        'amount': amount ?? 10,
        'unit': _unit,
        'rangeStart': _start == null ? null : Timestamp.fromDate(_start!),
        'rangeEnd': _end == null ? null : Timestamp.fromDate(_end!),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': adminEmail,
      },
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Sync threshold'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'rolling', label: Text('Rolling')),
              ButtonSegment(value: 'range', label: Text('Date range')),
            ],
            selected: {_mode},
            onSelectionChanged: (value) => setState(() => _mode = value.first),
          ),
          const SizedBox(height: 18),
          if (_mode == 'rolling') ...[
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _unit,
              decoration: const InputDecoration(
                labelText: 'Unit',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'days', child: Text('Days')),
                DropdownMenuItem(value: 'months', child: Text('Months')),
                DropdownMenuItem(value: 'years', child: Text('Years')),
              ],
              onChanged: (value) => setState(() => _unit = value ?? 'days'),
            ),
          ] else ...[
            ListTile(
              title: const Text('Start date'),
              subtitle: Text(
                _start == null
                    ? 'Select'
                    : '${_start!.day}/${_start!.month}/${_start!.year}',
              ),
              onTap: () => _pick(true),
            ),
            ListTile(
              title: const Text('End date'),
              subtitle: Text(
                _end == null
                    ? 'Select'
                    : '${_end!.day}/${_end!.month}/${_end!.year}',
              ),
              onTap: () => _pick(false),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving…' : 'Apply'),
      ),
    ],
  );
}
