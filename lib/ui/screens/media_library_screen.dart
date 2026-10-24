import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../providers/backup_provider.dart';
import '../../services/device_settings_helper.dart';
import '../../services/media_scanner_service.dart';
import '../widgets/media_folder_card.dart';
import '../widgets/media_item_tile.dart';
import 'media_preview_screen.dart';

class MediaLibraryScreen extends StatefulWidget {
  const MediaLibraryScreen({super.key});

  @override
  State<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends State<MediaLibraryScreen>
    with WidgetsBindingObserver {
  /// When null, we display the Folders/Albums grid.
  /// When non-null, we display the photos & videos inside that folder.
  String? _openedFolder;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAutoScanAndBackup();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final backup = context.read<BackupProvider>();
      if (backup.mediaItems.isEmpty && !backup.isScanning) {
        backup.startScan(forceFullScan: true);
      }
    }
  }

  Future<void> _initAutoScanAndBackup() async {
    // 1. Request initial permissions on launch: Photos, Notifications, Battery exemption
    await MediaScannerService.instance.requestAllAppPermissions();

    if (!mounted) return;

    final backup = context.read<BackupProvider>();

    // 2. Scan device media library immediately so albums load on screen and new media is discovered
    if (backup.mediaItems.isEmpty && !backup.isScanning) {
      await backup.startScan(forceFullScan: true);
    } else if (!backup.isScanning) {
      await backup.startScan(forceFullScan: false);
    }

    if (!mounted) return;

    // 3. Open Xiaomi Autostart settings screen on first launch for Redmi/Xiaomi devices
    // Run after the initial scan so albums are already loaded in memory and displayed
    DeviceSettingsHelper.checkAndOpenXiaomiAutostartOnFirstLaunch();
  }

  Map<String, List<MediaItem>> _groupItemsByFolder(List<MediaItem> items) {
    final map = <String, List<MediaItem>>{};
    for (final item in items) {
      final folder = item.displayFolderName;
      map.putIfAbsent(folder, () => []).add(item);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final backup = context.watch<BackupProvider>();

    final groupedFolders = _groupItemsByFolder(backup.mediaItems);
    // Sort folders by item count descending so prominent albums (Camera, WhatsApp, Screenshots) appear first
    final sortedFolderNames = groupedFolders.keys.toList()
      ..sort((a, b) => groupedFolders[b]!.length.compareTo(groupedFolders[a]!.length));

    // Intercept back button: if inside a folder, return to the Folders grid
    return PopScope(
      canPop: _openedFolder == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _openedFolder != null) {
          setState(() => _openedFolder = null);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.darkBg,
        appBar: AppBar(
          backgroundColor: AppTheme.darkBg,
          elevation: 0,
          leading: _openedFolder != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  tooltip: 'Back to Albums',
                  onPressed: () => setState(() => _openedFolder = null),
                )
              : null,
          title: _openedFolder != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _openedFolder!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _openedFolder == 'All Photos & Videos'
                          ? '${backup.mediaItems.length} items'
                          : '${groupedFolders[_openedFolder]?.length ?? 0} items',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                )
              : const Text(
                  'Gallery',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
          actions: [
            if (_openedFolder != null)
              IconButton(
                icon: const Icon(Icons.grid_view_rounded, color: Colors.white70),
                tooltip: 'All Albums',
                onPressed: () => setState(() => _openedFolder = null),
              ),
          ],
        ),
        body: SafeArea(
          child: _openedFolder == null
              ? _buildFoldersGrid(backup, groupedFolders, sortedFolderNames)
              : _buildFolderMediaGrid(backup, groupedFolders),
        ),
      ),
    );
  }

  /// Primary View: Shows all phone folders as album cards
  Widget _buildFoldersGrid(
    BackupProvider backup,
    Map<String, List<MediaItem>> groupedFolders,
    List<String> sortedFolderNames,
  ) {
    if (backup.mediaItems.isEmpty) {
      return RefreshIndicator(
        color: AppTheme.primaryAccent,
        backgroundColor: AppTheme.darkCard,
        onRefresh: () => backup.startScan(forceFullScan: true),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        backup.isScanning ? Icons.sync : Icons.photo_library_outlined,
                        size: 56,
                        color: backup.isScanning ? AppTheme.primaryAccent : Colors.white24,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        backup.isScanning
                            ? 'Scanning device albums...'
                            : 'No albums found on device',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        backup.isScanning
                            ? 'Indexing photos and videos from your device'
                            : 'Pull down to refresh or tap below to scan device albums',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ),
                      if (!backup.isScanning) ...[
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => backup.startScan(forceFullScan: true),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Scan Device Media'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final totalCount = backup.mediaItems.length;
    final totalFolders = sortedFolderNames.length;

    return RefreshIndicator(
      color: AppTheme.primaryAccent,
      backgroundColor: AppTheme.darkCard,
      onRefresh: () => backup.startScan(forceFullScan: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
        // Section Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.folder_copy_outlined,
                        size: 16, color: AppTheme.primaryAccent),
                    SizedBox(width: 8),
                    Text(
                      'Albums',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$totalFolders albums • $totalCount items',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2-Column Folders Grid
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.88,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                // First card is "All Photos & Videos"
                if (index == 0) {
                  return MediaFolderCard(
                    folderName: 'All Photos & Videos',
                    itemCount: totalCount,
                    coverItem: backup.mediaItems.isNotEmpty
                        ? backup.mediaItems.first
                        : null,
                    isAll: true,
                    onTap: () {
                      setState(() => _openedFolder = 'All Photos & Videos');
                    },
                  );
                }

                // Subsequent cards are individual phone folders
                final folderName = sortedFolderNames[index - 1];
                final folderItems = groupedFolders[folderName] ?? [];

                return MediaFolderCard(
                  folderName: folderName,
                  itemCount: folderItems.length,
                  coverItem: folderItems.isNotEmpty ? folderItems.first : null,
                  isAll: false,
                  onTap: () {
                    setState(() => _openedFolder = folderName);
                  },
                );
              },
              childCount: sortedFolderNames.length + 1,
            ),
          ),
        ),
      ],
    ),
  );
}

  /// Secondary View: Shows photos & videos inside the selected folder
  Widget _buildFolderMediaGrid(
    BackupProvider backup,
    Map<String, List<MediaItem>> groupedFolders,
  ) {
    final List<MediaItem> items;
    if (_openedFolder == 'All Photos & Videos') {
      items = backup.mediaItems;
    } else {
      items = groupedFolders[_openedFolder] ?? [];
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.perm_media_outlined, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              'No media in "$_openedFolder"',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryAccent,
      backgroundColor: AppTheme.darkCard,
      onRefresh: () => backup.startScan(forceFullScan: true),
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.82,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return MediaItemTile(
            key: ValueKey(item.localId),
            item: item,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MediaPreviewScreen(
                  items: items,
                  initialIndex: index,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
