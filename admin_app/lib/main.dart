import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

const adminEmail = 'balbirbisht372@gmail.com';
const driveOAuthClientId = String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID');
const driveOAuthClientSecret = String.fromEnvironment(
  'GOOGLE_OAUTH_CLIENT_SECRET',
);
const driveRefreshToken = String.fromEnvironment('GOOGLE_REFRESH_TOKEN');

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
  final String id, name, syncState, driveFolderName, driveFolderId;
  final DateTime? lastSeen;
  final int pendingFiles, driveFileCount, driveBytes;
  final List<DriveAlbumRecord> driveAlbums;
  final Map<String, dynamic>? syncPolicy;
  const DeviceRecord({
    required this.id,
    required this.name,
    required this.syncState,
    required this.driveFolderName,
    required this.driveFolderId,
    this.lastSeen,
    this.pendingFiles = 0,
    this.driveFileCount = 0,
    this.driveBytes = 0,
    this.driveAlbums = const [],
    this.syncPolicy,
  });
  bool get isOnline =>
      lastSeen != null && DateTime.now().difference(lastSeen!).inMinutes < 20;
  factory DeviceRecord.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final summary = data['driveSummary'] as Map<String, dynamic>?;
    return DeviceRecord(
      id: doc.id,
      name: data['name']?.toString() ?? 'Unknown device',
      syncState: data['syncState']?.toString() ?? 'idle',
      driveFolderName:
          data['driveFolderName']?.toString() ??
          data['name']?.toString() ??
          'Phone_Device',
      driveFolderId: summary?['folderId']?.toString() ?? '',
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
      pendingFiles: (data['pendingFiles'] as num?)?.toInt() ?? 0,
      driveFileCount: (summary?['fileCount'] as num?)?.toInt() ?? 0,
      driveBytes: (summary?['totalBytes'] as num?)?.toInt() ?? 0,
      driveAlbums: (summary?['folders'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((folder) => DriveAlbumRecord.fromMap(folder))
          .toList(),
      syncPolicy: data['syncPolicy'] is Map
          ? Map<String, dynamic>.from(data['syncPolicy'] as Map)
          : null,
    );
  }
}

class DriveAlbumRecord {
  final String name;
  final int fileCount, totalBytes;
  const DriveAlbumRecord({
    required this.name,
    required this.fileCount,
    required this.totalBytes,
  });
  factory DriveAlbumRecord.fromMap(Map<dynamic, dynamic> value) =>
      DriveAlbumRecord(
        name: value['name']?.toString() ?? 'Unknown folder',
        fileCount: (value['fileCount'] as num?)?.toInt() ?? 0,
        totalBytes: (value['totalBytes'] as num?)?.toInt() ?? 0,
      );
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

  Future<void> _editSyncPolicy(
    BuildContext context,
    DeviceRecord device,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => SyncPolicyDialog(
        deviceId: device.id,
        deviceName: device.name,
        initial: device.syncPolicy,
      ),
    );
  }

  void _showDriveData(BuildContext context, DeviceRecord device) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device.name,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('PhoneBackup/${device.driveFolderName}'),
              const SizedBox(height: 12),
              Text(
                '${device.driveFileCount} files • ${_formatBytes(device.driveBytes)}',
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: device.driveFolderId.isEmpty
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DriveMediaBrowser(
                              deviceName: device.name,
                              folderId: device.driveFolderId,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('View photos and videos'),
                ),
              ),
              const Divider(height: 28),
              if (device.driveAlbums.isEmpty)
                const Text(
                  'Folder data will appear after the normal app completes its next Drive refresh.',
                ),
              ...device.driveAlbums.map(
                (album) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder, color: Color(0xFF007AFF)),
                  title: Text(album.name),
                  subtitle: Text(
                    '${album.fileCount} files • ${_formatBytes(album.totalBytes)}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
                    '${device.syncState} • ${device.pendingFiles} pending • '
                    '${device.driveFileCount} Drive files\n'
                    'Drive: PhoneBackup/${device.driveFolderName}\n'
                    'Threshold: ${_policyLabel(device.syncPolicy)}',
                  ),
                  isThreeLine: true,
                  onTap: () => _showDriveData(context, device),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'start') {
                        _startSync(context, device);
                      } else if (action == 'threshold') {
                        _editSyncPolicy(context, device);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'start',
                        child: ListTile(
                          leading: Icon(Icons.sync),
                          title: Text('Start sync'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'threshold',
                        child: ListTile(
                          leading: Icon(Icons.date_range),
                          title: Text('Edit threshold'),
                        ),
                      ),
                    ],
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
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _policyLabel(Map<String, dynamic>? policy) {
    if (policy == null) return '10 days (default)';
    if (policy['mode'] == 'range') {
      return '${_dateLabel(policy['rangeStart'])} – ${_dateLabel(policy['rangeEnd'])}';
    }
    return '${policy['amount'] ?? 10} ${policy['unit'] ?? 'days'}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _BearerDriveClient extends http.BaseClient {
  final String authorization;
  final http.Client _inner = http.Client();

  _BearerDriveClient(this.authorization);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = authorization;
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

class DriveMediaBrowser extends StatefulWidget {
  final String deviceName, folderId;
  const DriveMediaBrowser({
    super.key,
    required this.deviceName,
    required this.folderId,
  });
  @override
  State<DriveMediaBrowser> createState() => _DriveMediaBrowserState();
}

class _DriveMediaBrowserState extends State<DriveMediaBrowser> {
  final _signIn = GoogleSignIn(
    clientId: driveOAuthClientId.isEmpty ? null : driveOAuthClientId,
    scopes: const [drive.DriveApi.driveReadonlyScope],
  );
  List<drive.File> _files = const [];
  Map<String, String> _headers = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Map<String, String>?> _refreshDirectCredentials() async {
    if (driveOAuthClientId.isEmpty ||
        driveOAuthClientSecret.isEmpty ||
        driveRefreshToken.isEmpty) {
      return null;
    }

    final response = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': driveOAuthClientId,
        'client_secret': driveOAuthClientSecret,
        'refresh_token': driveRefreshToken,
        'grant_type': 'refresh_token',
      },
    );

    if (response.statusCode != 200) {
      throw StateError(
        'Google Drive authorization failed (${response.statusCode}). '
        'Check the existing OAuth refresh credentials.',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = data['access_token']?.toString();
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Google Drive returned no access token.');
    }
    return {'Authorization': 'Bearer $accessToken'};
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      late http.Client client;
      late Map<String, String> headers;
      final directHeaders = await _refreshDirectCredentials();

      if (directHeaders != null) {
        headers = directHeaders;
        client = _BearerDriveClient(directHeaders['Authorization']!);
      } else {
        final account = await _signIn.signInSilently();
        if (account == null) {
          throw StateError(
            'Google Drive credentials are unavailable. Build the admin app with the existing OAuth credentials.',
          );
        }
        if (account.email.toLowerCase() != adminEmail.toLowerCase()) {
          await _signIn.signOut();
          throw StateError('Please sign in with $adminEmail');
        }
        client =
            await _signIn.authenticatedClient() ??
            (throw StateError('Unable to authorize Google Drive'));
        headers = await account.authHeaders;
      }

      final api = drive.DriveApi(client);

      final result = <drive.File>[];
      final seenFiles = <String>{};
      final foldersToScan = <String>[widget.folderId];
      final scannedFolders = <String>{};

      while (foldersToScan.isNotEmpty) {
        final folderId = foldersToScan.removeAt(0);
        if (!scannedFolders.add(folderId)) continue;

        String? token;
        do {
          final page = await api.files.list(
            q: "'$folderId' in parents and trashed = false",
            spaces: 'drive',
            pageSize: 1000,
            pageToken: token,
            supportsAllDrives: true,
            includeItemsFromAllDrives: true,
            $fields: 'nextPageToken,files(id,name,mimeType,thumbnailLink,size,createdTime,modifiedTime,webContentLink)',
          );

          for (final file in page.files ?? const <drive.File>[]) {
            final id = file.id;
            if (id == null || id.isEmpty) continue;

            if (file.mimeType == 'application/vnd.google-apps.folder') {
              if (!scannedFolders.contains(id)) foldersToScan.add(id);
              continue;
            }

            final mimeType = file.mimeType?.toLowerCase() ?? '';
            if ((mimeType.startsWith('image/') ||
                    mimeType.startsWith('video/')) &&
                seenFiles.add(id)) {
              result.add(file);
            }
          }
          token = page.nextPageToken;
        } while (token != null && token.isNotEmpty);
      }

      result.sort((a, b) {
        final aTime = a.createdTime ?? a.modifiedTime;
        final bTime = b.createdTime ?? b.modifiedTime;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _files = result;
          _headers = headers;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('${widget.deviceName} Drive'),
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          )
        : _files.isEmpty
        ? const Center(child: Text('No photos or videos found.'))
        : LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1000
                  ? 5
                  : constraints.maxWidth >= 600
                  ? 4
                  : 3;
              return GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final file = _files[index];
                  final isVideo = file.mimeType?.startsWith('video/') ?? false;
                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DriveMediaPreview(
                          files: _files,
                          initialIndex: index,
                          headers: _headers,
                        ),
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _preview(file, isVideo),
                        if (isVideo)
                          const Center(
                            child: CircleAvatar(child: Icon(Icons.play_arrow)),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
  );

  Widget _preview(drive.File file, bool isVideo, {bool large = false}) {
    if (large) {
      final webContentLink = file.webContentLink;
      if (webContentLink != null && webContentLink.isNotEmpty) {
        return Image.network(
          webContentLink,
          headers: _headers,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              _thumbnailPreview(file, isVideo, large: true),
        );
      }
    }

    return _thumbnailPreview(file, isVideo, large: large);
  }

  Widget _thumbnailPreview(
    drive.File file,
    bool isVideo, {
    bool large = false,
  }) {
    final link = file.thumbnailLink;
    if (link == null || link.isEmpty) {
      return Container(
        color: Colors.black12,
        child: Icon(isVideo ? Icons.videocam : Icons.image),
      );
    }
    final largeLink = large && link.contains('=')
        ? '${link.substring(0, link.lastIndexOf('='))}=s2048'
        : link;
    return Image.network(
      largeLink,
      headers: _headers,
      fit: large ? BoxFit.contain : BoxFit.cover,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Colors.black12,
        child: Icon(Icons.broken_image_outlined),
      ),
    );
  }
}

class DriveMediaPreview extends StatefulWidget {
  final List<drive.File> files;
  final int initialIndex;
  final Map<String, String> headers;
  const DriveMediaPreview({
    super.key,
    required this.files,
    required this.initialIndex,
    required this.headers,
  });
  @override
  State<DriveMediaPreview> createState() => _DriveMediaPreviewState();
}

class _DriveMediaPreviewState extends State<DriveMediaPreview> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.files[_index].name ?? 'Drive media',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            '${_index + 1} of ${widget.files.length}',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    ),
    body: PageView.builder(
      controller: _pageController,
      itemCount: widget.files.length,
      onPageChanged: (index) => setState(() => _index = index),
      itemBuilder: (context, index) {
        final file = widget.files[index];
        final isVideo = file.mimeType?.startsWith('video/') ?? false;
        if (isVideo) {
          return DriveVideoPage(
            file: file,
            headers: widget.headers,
            active: index == _index,
          );
        }
        final url =
            'https://www.googleapis.com/drive/v3/files/${file.id}?alt=media';
        return InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: Image.network(
              url,
              headers: widget.headers,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
              errorBuilder: (_, _, _) => const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white70,
                  size: 64,
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class DriveVideoPage extends StatefulWidget {
  final drive.File file;
  final Map<String, String> headers;
  final bool active;
  const DriveVideoPage({
    super.key,
    required this.file,
    required this.headers,
    required this.active,
  });
  @override
  State<DriveVideoPage> createState() => _DriveVideoPageState();
}

class _DriveVideoPageState extends State<DriveVideoPage> {
  late final VideoPlayerController _controller;
  late final Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(
        'https://www.googleapis.com/drive/v3/files/${widget.file.id}?alt=media',
      ),
      httpHeaders: widget.headers,
    )..addListener(_refresh);
    _ready = _controller.initialize().then((_) {
      if (widget.active) _controller.play();
    });
  }

  @override
  void didUpdateWidget(covariant DriveVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && _controller.value.isPlaying) {
      _controller.pause();
    } else if (widget.active &&
        !oldWidget.active &&
        _controller.value.isInitialized) {
      _controller.play();
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(
          child: Text(
            'Unable to play this video.',
            style: TextStyle(color: Colors.white),
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      return Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _controller.value.isPlaying
                  ? _controller.pause()
                  : _controller.play(),
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(_controller),
                      if (!_controller.value.isPlaying)
                        const CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.black54,
                          child: Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 42,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Row(
              children: [
                IconButton(
                  color: Colors.white,
                  onPressed: () => _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play(),
                  icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                ),
                Expanded(
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Color(0xFF007AFF),
                      bufferedColor: Colors.white38,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class SyncPolicyDialog extends StatefulWidget {
  final String deviceId, deviceName;
  final Map<String, dynamic>? initial;
  const SyncPolicyDialog({
    super.key,
    required this.deviceId,
    required this.deviceName,
    this.initial,
  });
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
    final existing = (start ? _start : _end) ?? DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDate: existing,
    );
    if (selectedDate == null || !mounted) return;
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(existing),
    );
    if (selectedTime != null) {
      final selected = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
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
    await FirebaseFirestore.instance
        .collection('devices')
        .doc(widget.deviceId)
        .update({
          'syncPolicy': {
            'mode': _mode,
            'amount': amount ?? 10,
            'unit': _unit,
            'rangeStart': _start == null ? null : Timestamp.fromDate(_start!),
            'rangeEnd': _end == null ? null : Timestamp.fromDate(_end!),
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': adminEmail,
          },
        });
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${widget.deviceName} threshold'),
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
                _start == null ? 'Select' : _formatDateTime(_start!),
              ),
              onTap: () => _pick(true),
            ),
            ListTile(
              title: const Text('End date'),
              subtitle: Text(_end == null ? 'Select' : _formatDateTime(_end!)),
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

  String _formatDateTime(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
