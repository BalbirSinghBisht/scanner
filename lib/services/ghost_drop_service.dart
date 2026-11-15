import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/utils/zip_archive_builder.dart';
import '../models/media_item.dart';
import 'media_scanner_service.dart';

class GhostDropService extends ChangeNotifier {
  static final GhostDropService instance = GhostDropService._internal();

  GhostDropService._internal();

  HttpServer? _server;
  List<MediaItem> _currentItems = [];
  String? _serverUrl;
  bool _isRunning = false;
  int _connectedClients = 0;
  String _activeStatus = 'Ready for connection...';
  int _downloadCount = 0;

  bool get isRunning => _isRunning;
  String? get serverUrl => _serverUrl;
  int get connectedClients => _connectedClients;
  String get activeStatus => _activeStatus;
  int get downloadCount => _downloadCount;
  List<MediaItem> get currentItems => List.unmodifiable(_currentItems);

  int get totalSizeBytes =>
      _currentItems.fold(0, (sum, item) => sum + item.fileSize);

  String get formattedTotalSize {
    final bytes = totalSizeBytes;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<String?> startSession({required List<MediaItem> items}) async {
    if (items.isEmpty) return null;
    await stopSession();

    _currentItems = List.from(items);
    _downloadCount = 0;
    _connectedClients = 0;
    _activeStatus = 'Discovering local network IP...';
    notifyListeners();

    // 1. Discover local Wi-Fi / Hotspot IPv4 address
    String? localIp;
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            final a = addr.address;
            if (a.startsWith('192.168.') ||
                a.startsWith('10.') ||
                a.startsWith('172.')) {
              localIp = a;
              break;
            }
          }
        }
        if (localIp != null) break;
      }
      if (localIp == null && interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        localIp = interfaces.first.addresses.first.address;
      }
    } catch (e) {
      debugPrint('[GhostDrop] Interface discovery error: $e');
    }

    localIp ??= '127.0.0.1';

    // 2. Bind local HTTP server on random open port
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      _serverUrl = 'http://$localIp:${_server!.port}';
      _isRunning = true;
      _activeStatus = 'Waiting for peer to scan QR code...';
      notifyListeners();

      _listenToRequests();
      debugPrint('[GhostDrop] Server active at: $_serverUrl');
      return _serverUrl;
    } catch (e) {
      _activeStatus = 'Failed to start local server: $e';
      _isRunning = false;
      notifyListeners();
      return null;
    }
  }

  void _listenToRequests() {
    _server?.listen((HttpRequest req) async {
      try {
        final path = req.uri.path;
        final clientIp = req.connectionInfo?.remoteAddress.address ?? 'Peer';

        if (path == '/' || path == '/index.html') {
          _connectedClients++;
          _activeStatus = 'Connected: $clientIp is viewing files';
          notifyListeners();

          req.response.headers.contentType = ContentType.html;
          req.response.write(_generateWebPortalHtml());
          await req.response.close();
        } else if (path == '/file') {
          final id = req.uri.queryParameters['id'];
          final item = _currentItems.firstWhere(
            (it) => it.localId == id,
            orElse: () => _currentItems.first,
          );

          File? file;
          if (item.localFilePath != null && File(item.localFilePath!).existsSync()) {
            file = File(item.localFilePath!);
          } else {
            file = await MediaScannerService.instance.getMediaFile(item.localId);
          }

          if (file != null && await file.exists()) {
            _downloadCount++;
            _activeStatus = 'Sending ${item.fileName} to $clientIp...';
            notifyListeners();

            final length = await file.length();
            req.response.headers.set('Content-Type', item.mimeType);
            req.response.headers.set(
              'Content-Disposition',
              'attachment; filename="${Uri.encodeComponent(item.fileName)}"',
            );
            req.response.headers.set('Content-Length', length.toString());
            await file.openRead().pipe(req.response);
          } else {
            req.response.statusCode = HttpStatus.notFound;
            req.response.write('File not found');
            await req.response.close();
          }
        } else if (path == '/thumb') {
          final id = req.uri.queryParameters['id'];
          final item = _currentItems.firstWhere(
            (it) => it.localId == id,
            orElse: () => _currentItems.first,
          );

          File? file;
          if (item.localFilePath != null && File(item.localFilePath!).existsSync()) {
            file = File(item.localFilePath!);
          } else {
            file = await MediaScannerService.instance.getMediaFile(item.localId);
          }

          if (file != null && await file.exists()) {
            req.response.headers.set('Content-Type', item.mimeType);
            await file.openRead().pipe(req.response);
          } else {
            req.response.statusCode = HttpStatus.notFound;
            await req.response.close();
          }
        } else if (path == '/zip') {
          _activeStatus = 'Archiving all files into ZIP for $clientIp...';
          notifyListeners();

          final filesMap = <String, List<int>>{};
          for (final it in _currentItems) {
            File? f;
            if (it.localFilePath != null && File(it.localFilePath!).existsSync()) {
              f = File(it.localFilePath!);
            } else {
              f = await MediaScannerService.instance.getMediaFile(it.localId);
            }
            if (f != null && await f.exists()) {
              final bytes = await f.readAsBytes();
              filesMap[it.fileName] = bytes;
            }
          }

          final zipBytes = ZipArchiveBuilder.buildZip(filesMap);
          _downloadCount++;
          _activeStatus = 'Sent ZIP package to $clientIp!';
          notifyListeners();

          req.response.headers.set('Content-Type', 'application/zip');
          req.response.headers.set(
            'Content-Disposition',
            'attachment; filename="GhostDrop_Bundle.zip"',
          );
          req.response.headers.set('Content-Length', zipBytes.length.toString());
          req.response.add(zipBytes);
          await req.response.close();
        } else {
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        }
      } catch (e) {
        debugPrint('[GhostDrop] HTTP Request error: $e');
        try {
          req.response.statusCode = HttpStatus.internalServerError;
          await req.response.close();
        } catch (_) {}
      }
    });
  }

  Future<void> stopSession() async {
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _serverUrl = null;
    _isRunning = false;
    _connectedClients = 0;
    _activeStatus = 'Session ended';
    notifyListeners();
  }

  String _generateWebPortalHtml() {
    final totalSizeStr = formattedTotalSize;
    final fileCount = _currentItems.length;

    final cardsHtml = StringBuffer();
    for (int i = 0; i < _currentItems.length; i++) {
      final it = _currentItems[i];
      final isVideo = it.isVideo;
      final encodedName = Uri.encodeComponent(it.fileName);

      cardsHtml.write('''
      <div class="card">
        <div class="thumb-container">
          ${isVideo
              ? '<div class="video-pill">VIDEO</div>'
              : '<img src="/thumb?id=${it.localId}" loading="lazy" alt="$encodedName" />'
          }
        </div>
        <div class="card-info">
          <div class="card-title" title="${it.fileName}">${it.fileName}</div>
          <div class="card-size">${it.formattedSize}</div>
        </div>
        <a class="btn-download" href="/file?id=${it.localId}" download="${it.fileName}">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
            <polyline points="7 10 12 15 17 10"></polyline>
            <line x1="12" y1="15" x2="12" y2="3"></line>
          </svg>
          Download
        </a>
      </div>
      ''');
    }

    return '''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" />
      <title>GhostDrop · High-Speed P2P Beam</title>
      <style>
        :root {
          --bg: #09090b;
          --card: #18181b;
          --border: rgba(255, 255, 255, 0.1);
          --primary: #3b82f6;
          --primary-hover: #2563eb;
          --text: #fafafa;
          --text-muted: #a1a1aa;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
        body { background: var(--bg); color: var(--text); padding: 20px 16px 60px 16px; min-height: 100vh; }
        .header { text-align: center; margin-bottom: 24px; padding-top: 10px; }
        .logo-badge {
          display: inline-flex; align-items: center; gap: 6px;
          background: rgba(59, 130, 246, 0.15); border: 1px solid rgba(59, 130, 246, 0.3);
          color: #60a5fa; font-size: 12px; font-weight: 700; text-transform: uppercase;
          letter-spacing: 1px; padding: 5px 12px; border-radius: 20px; margin-bottom: 12px;
        }
        h1 { font-size: 26px; font-weight: 800; letter-spacing: -0.5px; margin-bottom: 6px; }
        .meta { color: var(--text-muted); font-size: 14px; margin-bottom: 18px; }
        .btn-zip {
          display: inline-flex; align-items: center; justify-content: center; gap: 8px;
          background: var(--primary); color: #fff; text-decoration: none; font-weight: 600;
          font-size: 15px; padding: 12px 24px; border-radius: 12px; transition: 0.2s;
          box-shadow: 0 4px 14px rgba(59, 130, 246, 0.4);
        }
        .btn-zip:hover { background: var(--primary-hover); }
        .grid {
          display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
          gap: 14px; max-width: 900px; margin: 0 auto;
        }
        .card {
          background: var(--card); border: 1px solid var(--border); border-radius: 16px;
          overflow: hidden; display: flex; flex-direction: column; transition: transform 0.2s;
        }
        .card:hover { transform: translateY(-2px); border-color: rgba(255,255,255,0.2); }
        .thumb-container {
          width: 100%; aspect-ratio: 1; background: #27272a; position: relative;
          display: flex; align-items: center; justify-content: center; overflow: hidden;
        }
        .thumb-container img { width: 100%; height: 100%; object-fit: cover; }
        .video-pill {
          background: rgba(0,0,0,0.7); padding: 4px 8px; border-radius: 6px;
          font-size: 10px; font-weight: 700; letter-spacing: 0.5px;
        }
        .card-info { padding: 10px; flex-grow: 1; }
        .card-title {
          font-size: 13px; font-weight: 600; white-space: nowrap; overflow: hidden;
          text-overflow: ellipsis; margin-bottom: 2px;
        }
        .card-size { font-size: 11px; color: var(--text-muted); }
        .btn-download {
          display: flex; align-items: center; justify-content: center; gap: 6px;
          background: rgba(255, 255, 255, 0.08); color: var(--text); text-decoration: none;
          font-size: 12px; font-weight: 600; padding: 8px 12px; border-top: 1px solid var(--border);
          transition: 0.15s;
        }
        .btn-download:hover { background: var(--primary); color: #fff; }
      </style>
    </head>
    <body>
      <div class="header">
        <div class="logo-badge">⚡ GhostDrop Local Beam</div>
        <h1>Direct Device Transfer</h1>
        <div class="meta">$fileCount files · $totalSizeStr · Zero Cloud & Zero Compression</div>
        <a class="btn-zip" href="/zip">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="21 8 21 21 3 21 3 8"></polyline>
            <rect x="1" y="3" width="22" height="5"></rect>
            <line x1="10" y1="12" x2="14" y2="12"></line>
          </svg>
          Download All ($totalSizeStr .ZIP)
        </a>
      </div>
      <div class="grid">
        $cardsHtml
      </div>
    </body>
    </html>
    ''';
  }
}
