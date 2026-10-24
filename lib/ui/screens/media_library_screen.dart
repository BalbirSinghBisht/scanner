import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../providers/backup_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/media_folder_card.dart';
import '../widgets/media_item_tile.dart';

class MediaLibraryScreen extends StatefulWidget {
  const MediaLibraryScreen({super.key});

  @override
  State<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends State<MediaLibraryScreen> {
  /// When null, we display the Folders/Albums grid.
  /// When non-null, we display the photos & videos inside that folder.
  String? _openedFolder;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAutoScanAndBackup();
    });
  }

  Future<void> _initAutoScanAndBackup() async {
    final backup = context.read<BackupProvider>();
    if (backup.mediaItems.isEmpty && !backup.isScanning) {
      await backup.startScan();
    } else if (backup.mediaItems.isNotEmpty && !backup.isSyncing) {
      final settings = context.read<SettingsProvider>().settings;
      await backup.startBackup(settings, isManual: true);
    }
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              backup.isScanning ? Icons.sync : Icons.folder_open_outlined,
              size: 56,
              color: Colors.white24,
            ),
            const SizedBox(height: 12),
            Text(
              backup.isScanning
                  ? 'Scanning device albums...'
                  : 'No albums found on device',
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

    final totalCount = backup.mediaItems.length;
    final totalFolders = sortedFolderNames.length;

    return CustomScrollView(
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

    return GridView.builder(
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
        );
      },
    );
  }
}
