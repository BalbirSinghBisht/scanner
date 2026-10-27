import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../providers/backup_provider.dart';
import '../../services/device_settings_helper.dart';
import '../../services/favorites_service.dart';
import '../../services/media_scanner_service.dart';
import '../widgets/media_folder_card.dart';
import '../widgets/media_item_tile.dart';
import '../widgets/three_d_carousel.dart';
import 'media_preview_screen.dart';

enum SortMode {
  newest,
  oldest,
  size,
  name,
}

enum MediaFilter {
  all,
  photos,
  videos,
  favorites,
}

class MediaLibraryScreen extends StatefulWidget {
  const MediaLibraryScreen({super.key});

  @override
  State<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends State<MediaLibraryScreen>
    with WidgetsBindingObserver {
  // Navigation: 0 = Photos (Timeline), 1 = Albums (3D Stacks), 2 = Favorites
  int _currentTabIndex = 0;

  /// When null, we display the Folders/Albums grid.
  /// When non-null, we display the photos & videos inside that folder.
  String? _openedFolder;

  // Search & Filter state
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  MediaFilter _activeFilter = MediaFilter.all;
  SortMode _sortMode = SortMode.newest;

  // View density: 2 (Cinematic), 3 (Standard), 4 (Dense)
  int _gridColumns = 3;

  // Featured 3D Coverflow visibility
  static const String _keyShowFeatured = 'gallery_show_featured_moments';
  bool _showFeaturedShowcase = true;

  // Multi-Selection state
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFeaturedPreference();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAutoScanAndBackup();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFeaturedPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pref = prefs.getBool(_keyShowFeatured);
      if (pref != null && mounted) {
        setState(() => _showFeaturedShowcase = pref);
      }
    } catch (_) {}
  }

  Future<void> _toggleFeaturedMoments(bool show) async {
    setState(() => _showFeaturedShowcase = show);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyShowFeatured, show);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final backup = context.read<BackupProvider>();
      MediaScannerService.instance.requestPermission().then((_) {
        if (MediaScannerService.instance.isPermissionGranted) {
          if (!backup.isScanning) {
            backup.startScan(forceFullScan: true);
          }
        }
      });
    }
  }

  Future<void> _initAutoScanAndBackup() async {
    await MediaScannerService.instance.requestAllAppPermissions();
    if (!mounted) return;

    final backup = context.read<BackupProvider>();
    if (!backup.isScanning) {
      await backup.startScan(forceFullScan: true);
    }
    if (!mounted) return;

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

  /// Groups items by human-friendly date headers for the flagship timeline
  Map<String, List<MediaItem>> _groupByDate(List<MediaItem> items) {
    final map = <String, List<MediaItem>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final item in items) {
      final itemDate = DateTime(item.createdAt.year, item.createdAt.month, item.createdAt.day);
      String label;
      if (itemDate == today) {
        label = 'Today';
      } else if (itemDate == yesterday) {
        label = 'Yesterday';
      } else if (item.createdAt.year == now.year) {
        label = DateFormat('MMMM d').format(item.createdAt);
      } else {
        label = DateFormat('MMMM yyyy').format(item.createdAt);
      }
      map.putIfAbsent(label, () => []).add(item);
    }
    return map;
  }

  List<MediaItem> _filterAndSortItems(List<MediaItem> items) {
    var result = List<MediaItem>.from(items);

    // 1. Search Query Filter
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((it) =>
              it.fileName.toLowerCase().contains(q) ||
              it.displayFolderName.toLowerCase().contains(q))
          .toList();
    }

    // 2. Category Filter
    switch (_activeFilter) {
      case MediaFilter.photos:
        result = result.where((it) => it.mediaType == AppMediaType.image).toList();
        break;
      case MediaFilter.videos:
        result = result.where((it) => it.mediaType == AppMediaType.video).toList();
        break;
      case MediaFilter.favorites:
        final favs = FavoritesService.instance.favoriteIds;
        result = result.where((it) => favs.contains(it.localId)).toList();
        break;
      case MediaFilter.all:
        break;
    }

    // 3. Sorting
    switch (_sortMode) {
      case SortMode.newest:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortMode.oldest:
        result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortMode.size:
        result.sort((a, b) => b.fileSize.compareTo(a.fileSize));
        break;
      case SortMode.name:
        result.sort((a, b) => a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()));
        break;
    }

    return result;
  }

  void _toggleSelection(String localId) {
    setState(() {
      if (_selectedIds.contains(localId)) {
        _selectedIds.remove(localId);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(localId);
      }
    });
  }

  void _enterSelectionMode(String initialId) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(initialId);
    });
  }

  void _selectAll(List<MediaItem> items) {
    setState(() {
      if (_selectedIds.length == items.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.addAll(items.map((e) => e.localId));
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelectDateGroup(List<MediaItem> items) {
    if (items.isEmpty) return;
    final allInGroupSelected = items.every((it) => _selectedIds.contains(it.localId));
    setState(() {
      if (!_isSelectionMode) {
        _isSelectionMode = true;
      }
      if (allInGroupSelected) {
        for (final it in items) {
          _selectedIds.remove(it.localId);
        }
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        for (final it in items) {
          _selectedIds.add(it.localId);
        }
      }
    });
  }

  Future<void> _batchShareSelected(List<MediaItem> allItems) async {
    final selectedItems = allItems.where((it) => _selectedIds.contains(it.localId)).toList();
    if (selectedItems.isEmpty) return;

    final filePaths = <String>[];
    for (final item in selectedItems) {
      File? file;
      if (item.localFilePath != null) {
        final f = File(item.localFilePath!);
        if (await f.exists()) file = f;
      }
      file ??= await MediaScannerService.instance.getMediaFile(item.localId);
      if (file != null && await file.exists()) {
        filePaths.add(file.path);
      }
    }

    if (filePaths.isNotEmpty) {
      if (filePaths.length == 1) {
        await DeviceSettingsHelper.shareMediaFile(filePaths.first, selectedItems.first.mimeType);
      } else {
        await DeviceSettingsHelper.shareMultipleMediaFiles(filePaths);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected files could not be accessed'),
            backgroundColor: AppTheme.roseDanger,
          ),
        );
      }
    }
  }

  Future<void> _batchDeleteSelected(List<MediaItem> allItems) async {
    final selectedItems = allItems.where((it) => _selectedIds.contains(it.localId)).toList();
    if (selectedItems.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D31),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: Colors.white.withOpacity(0.12), width: 1.2),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded, color: AppTheme.roseDanger, size: 24),
            const SizedBox(width: 10),
            Text('Delete ${selectedItems.length} items?',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete these ${selectedItems.length} files permanently from your device storage?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.roseDanger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final backup = context.read<BackupProvider>();
      for (final item in selectedItems) {
        await backup.deleteMediaItem(item);
      }
      _exitSelectionMode();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedItems.length} items deleted'),
            backgroundColor: const Color(0xFF1C2740),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _batchToggleFavorites(List<MediaItem> allItems) async {
    final favService = FavoritesService.instance;
    final selectedItems = allItems.where((it) => _selectedIds.contains(it.localId)).toList();
    if (selectedItems.isEmpty) return;

    final allFavorited = selectedItems.every((it) => favService.isFavorite(it.localId));
    for (final it in selectedItems) {
      await favService.setFavorite(it.localId, !allFavorited);
    }
    setState(() {});
  }

  void _showSortOptionsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        padding: EdgeInsets.only(
          top: 14,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sort Gallery',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            _buildSortOption(SortMode.newest, 'Newest First', CupertinoIcons.clock),
            _buildSortOption(SortMode.oldest, 'Oldest First', CupertinoIcons.time),
            _buildSortOption(SortMode.size, 'File Size (Largest)', CupertinoIcons.square_stack_3d_up),
            _buildSortOption(SortMode.name, 'Name (A to Z)', CupertinoIcons.textformat_abc),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(SortMode mode, String label, IconData icon) {
    final isSelected = _sortMode == mode;
    return InkWell(
      onTap: () {
        setState(() => _sortMode = mode);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.appleBlue.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? AppTheme.appleBlue : Colors.white54),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.appleBlue : Colors.white,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 15,
                letterSpacing: -0.2,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(CupertinoIcons.checkmark, color: AppTheme.appleBlue, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backup = context.watch<BackupProvider>();
    final favService = FavoritesService.instance;

    return ListenableBuilder(
      listenable: favService,
      builder: (context, _) {
        final groupedFolders = _groupItemsByFolder(backup.mediaItems);
        final sortedFolderNames = groupedFolders.keys.toList()
          ..sort((a, b) => groupedFolders[b]!.length.compareTo(groupedFolders[a]!.length));

        // Reset opened folder if it was removed
        if (_openedFolder != null &&
            _openedFolder != 'All Photos & Videos' &&
            !groupedFolders.containsKey(_openedFolder)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _openedFolder != null && !groupedFolders.containsKey(_openedFolder)) {
              setState(() => _openedFolder = null);
            }
          });
        }

        // Determine active media items based on current tab or folder
        final List<MediaItem> currentMediaPool;
        if (_openedFolder != null) {
          currentMediaPool = _openedFolder == 'All Photos & Videos'
              ? backup.mediaItems
              : (groupedFolders[_openedFolder] ?? []);
        } else if (_currentTabIndex == 2) {
          // Favorites tab
          currentMediaPool = backup.mediaItems
              .where((it) => favService.isFavorite(it.localId))
              .toList();
        } else {
          currentMediaPool = backup.mediaItems;
        }

        return PopScope(
          canPop: _openedFolder == null && !_isSelectionMode && !_isSearchOpen && _currentTabIndex == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              if (_isSelectionMode) {
                _exitSelectionMode();
              } else if (_isSearchOpen) {
                setState(() {
                  _isSearchOpen = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              } else if (_openedFolder != null) {
                setState(() => _openedFolder = null);
              } else if (_currentTabIndex != 0) {
                setState(() => _currentTabIndex = 0);
              }
            }
          },
          child: Scaffold(
            backgroundColor: AppTheme.darkBg,
            body: Stack(
              children: [
                // Main Content View
                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      // Top Frosted App Bar / Selection Header
                      _buildTopBar(backup, currentMediaPool, groupedFolders, favService),

                      // Fixed 2px scanning indicator so layout never shifts or flickers
                      SizedBox(
                        height: 2,
                        child: backup.isScanning && backup.mediaItems.isNotEmpty
                            ? const LinearProgressIndicator(
                                minHeight: 2,
                                backgroundColor: Colors.transparent,
                                color: AppTheme.primaryAccent,
                              )
                            : const SizedBox.shrink(),
                      ),

                      // Animated Search Bar
                      if (_isSearchOpen) _buildSearchBar(),

                      // 3D Category Filter Strip (when not in Albums tab or when inside a folder)
                      if (_openedFolder != null || _currentTabIndex != 1)
                        _buildCategoryPillStrip(favService),

                      // Main Content Body
                      Expanded(
                        child: _buildCurrentTabContent(
                          backup,
                          groupedFolders,
                          sortedFolderNames,
                          currentMediaPool,
                        ),
                      ),
                    ],
                  ),
                ),

                // Apple Photos Bottom Tab Bar / Batch Actions Bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _isSelectionMode
                      ? _buildBatchActionBar(currentMediaPool)
                      : _buildFloatingBottomNav(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Apple Photos Top Navigation Bar: changes to selection toolbar when in batch mode
  Widget _buildTopBar(
    BackupProvider backup,
    List<MediaItem> currentPool,
    Map<String, List<MediaItem>> groupedFolders,
    FavoritesService favService,
  ) {
    if (_isSelectionMode) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.darkBg,
          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08), width: 0.5)),
        ),
        child: Row(
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 0,
              onPressed: _exitSelectionMode,
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppTheme.appleBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '${_selectedIds.length} Selected',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 0,
              onPressed: () => _selectAll(currentPool),
              child: Text(
                _selectedIds.length == currentPool.length ? 'Deselect All' : 'Select All',
                style: const TextStyle(
                  color: AppTheme.appleBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    String titleText = 'Library';
    if (_openedFolder != null) {
      titleText = _openedFolder!;
    } else if (_currentTabIndex == 1) {
      titleText = 'Albums';
    } else if (_currentTabIndex == 2) {
      titleText = 'Favorites';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      decoration: BoxDecoration(
        color: AppTheme.darkBg,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06), width: 0.5)),
      ),
      child: Row(
        children: [
          // Back button if folder opened
          if (_openedFolder != null) ...[
            CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 0,
              onPressed: () => setState(() => _openedFolder = null),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.chevron_back, color: AppTheme.appleBlue, size: 26),
                  Text('Albums', style: TextStyle(color: AppTheme.appleBlue, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Title in Apple Bold Typography
          Expanded(
            child: Text(
              titleText,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Search button
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            minSize: 0,
            onPressed: () {
              setState(() {
                _isSearchOpen = !_isSearchOpen;
                if (!_isSearchOpen) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
            child: Icon(
              _isSearchOpen ? CupertinoIcons.clear : CupertinoIcons.search,
              color: _isSearchOpen ? Colors.white : AppTheme.appleBlue,
              size: 22,
            ),
          ),

          // Density Switcher
          if (_currentTabIndex != 1 || _openedFolder != null)
            CupertinoButton(
              padding: const EdgeInsets.all(8),
              minSize: 0,
              onPressed: () {
                setState(() {
                  _gridColumns = _gridColumns == 2 ? 3 : (_gridColumns == 3 ? 4 : 2);
                });
              },
              child: Icon(
                _gridColumns == 2
                    ? CupertinoIcons.square_grid_2x2
                    : (_gridColumns == 3
                        ? CupertinoIcons.rectangle_grid_3x2
                        : CupertinoIcons.circle_grid_hex),
                color: AppTheme.appleBlue,
                size: 22,
              ),
            ),

          // Sort Options
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            minSize: 0,
            onPressed: _showSortOptionsDialog,
            child: const Icon(
              CupertinoIcons.arrow_up_arrow_down,
              color: AppTheme.appleBlue,
              size: 20,
            ),
          ),

          // Select button
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minSize: 0,
            onPressed: () {
              setState(() => _isSelectionMode = true);
            },
            child: const Text(
              'Select',
              style: TextStyle(
                color: AppTheme.appleBlue,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Apple Photos Search Bar
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.search, color: AppTheme.darkTextSecondary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Search photos, videos, albums',
                hintStyle: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 15),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
            ),
          ),
          if (_searchQuery.isNotEmpty)
            CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 0,
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: const Icon(CupertinoIcons.clear_circled_solid, color: AppTheme.darkTextSecondary, size: 18),
            ),
        ],
      ),
    );
  }

  /// Apple Photos Category Filter Strip
  Widget _buildCategoryPillStrip(FavoritesService favService) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          _buildFilterChip('All', CupertinoIcons.square_grid_2x2, MediaFilter.all),
          _buildFilterChip('Photos', CupertinoIcons.photo, MediaFilter.photos),
          _buildFilterChip('Videos', CupertinoIcons.videocam, MediaFilter.videos),
          _buildFilterChip(
            'Favorites (${favService.count})',
            CupertinoIcons.heart_fill,
            MediaFilter.favorites,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    IconData icon,
    MediaFilter filter,
  ) {
    final isSelected = _activeFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() => _activeFilter = filter);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.08),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.black : Colors.white70,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 12.5,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent(
    BackupProvider backup,
    Map<String, List<MediaItem>> groupedFolders,
    List<String> sortedFolderNames,
    List<MediaItem> currentPool,
  ) {
    if (_openedFolder != null) {
      return _buildFolderMediaView(backup, groupedFolders);
    }

    switch (_currentTabIndex) {
      case 1:
        // Albums Tab (3D Stacks + Featured Moments)
        return _buildFoldersView(backup, groupedFolders, sortedFolderNames);
      case 2:
        // Favorites Tab
        return _buildTimelineView(backup, currentPool, emptyMessage: 'No favorite items yet');
      case 0:
      default:
        // Photos Timeline Tab
        return _buildTimelineView(backup, currentPool, emptyMessage: 'No photos or videos');
    }
  }

  /// Flagship Timeline Photostream with Sticky Date Section Headers
  Widget _buildTimelineView(
    BackupProvider backup,
    List<MediaItem> rawItems, {
    String emptyMessage = 'No media found',
  }) {
    final filtered = _filterAndSortItems(rawItems);

    if (filtered.isEmpty) {
      if (backup.mediaItems.isEmpty) {
        return _buildEmptyState(backup);
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.darkCard,
                border: Border.all(color: Colors.white12),
              ),
              child: const Icon(Icons.photo_library_outlined, size: 44, color: Colors.white24),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No results for "$_searchQuery"' : emptyMessage,
              style: const TextStyle(fontSize: 15, color: Colors.white70, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    final dateGroups = _groupByDate(filtered);

    return RefreshIndicator(
      color: AppTheme.primaryAccent,
      backgroundColor: AppTheme.darkCard,
      onRefresh: () => backup.startScan(forceFullScan: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          for (final entry in dateGroups.entries) ...[
            // Apple Date Section Header
            SliverToBoxAdapter(
              child: Builder(
                builder: (context) {
                  final isGroupSelected = entry.value.isNotEmpty &&
                      entry.value.every((it) => _selectedIds.contains(it.localId));

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${entry.value.length}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.darkTextSecondary,
                          ),
                        ),
                        const Spacer(),
                        if (_isSelectionMode)
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minSize: 0,
                            onPressed: () => _toggleSelectDateGroup(entry.value),
                            child: Text(
                              isGroupSelected ? 'Deselect' : 'Select',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.appleBlue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Apple Photo Grid (Square 1:1, 2px spacing)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _gridColumns,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                  childAspectRatio: 1.0,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = entry.value[index];
                    final isSelected = _selectedIds.contains(item.localId);

                    return MediaItemTile(
                      key: ValueKey(item.localId),
                      item: item,
                      isSelectionMode: _isSelectionMode,
                      isSelected: isSelected,
                      onLongPress: () {
                        if (!_isSelectionMode) {
                          _enterSelectionMode(item.localId);
                        }
                      },
                      onTap: () {
                        if (_isSelectionMode) {
                          _toggleSelection(item.localId);
                        } else {
                          final globalIndex = filtered.indexOf(item);
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              opaque: false,
                              barrierColor: Colors.black,
                              reverseTransitionDuration: Duration.zero,
                              pageBuilder: (_, _, _) => MediaPreviewScreen(
                                items: filtered,
                                initialIndex: globalIndex != -1 ? globalIndex : 0,
                              ),
                              transitionsBuilder: (_, animation, _, child) =>
                                  FadeTransition(opacity: animation, child: child),
                              transitionDuration: const Duration(milliseconds: 180),
                            ),
                          );
                        }
                      },
                    );
                  },
                  childCount: entry.value.length,
                ),
              ),
            ),
          ],

          // Authentic Apple Photos Library Status Footer
          SliverToBoxAdapter(
            child: _buildLibraryStatusFooter(backup, rawItems),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryStatusFooter(BackupProvider backup, List<MediaItem> allItems) {
    final photoCount = allItems.where((i) => i.mediaType == AppMediaType.image).length;
    final videoCount = allItems.where((i) => i.mediaType == AppMediaType.video).length;

    String statusText;
    if (backup.isSyncing) {
      statusText = 'Syncing with Google Drive...';
    } else if (backup.isWaitingForNetwork) {
      statusText = 'Waiting for network connection';
    } else {
      statusText = 'Synced with Google Drive • Updated Just Now';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$photoCount Photos, $videoCount Videos',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (backup.isSyncing) ...[
                const CupertinoActivityIndicator(radius: 6, color: AppTheme.appleBlue),
                const SizedBox(width: 6),
              ],
              Text(
                statusText,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.darkTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 80), // Room for bottom tab bar
        ],
      ),
    );
  }

  /// Primary View: Shows 3D Showcase Carousel + Phone albums as 3D stacked cards
  Widget _buildFoldersView(
    BackupProvider backup,
    Map<String, List<MediaItem>> groupedFolders,
    List<String> sortedFolderNames,
  ) {
    if (backup.mediaItems.isEmpty) {
      return _buildEmptyState(backup);
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
          // 3D Featured Coverflow Carousel (if active filter is all and not searching)
          if (_showFeaturedShowcase &&
              _searchQuery.isEmpty &&
              _activeFilter == MediaFilter.all &&
              backup.mediaItems.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ThreeDShowcaseCarousel(
                  items: backup.mediaItems,
                  onDismiss: () => _toggleFeaturedMoments(false),
                ),
              ),
            )
          else if (!_showFeaturedShowcase &&
              _searchQuery.isEmpty &&
              _activeFilter == MediaFilter.all &&
              backup.mediaItems.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: InkWell(
                  onTap: () => _toggleFeaturedMoments(true),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primaryAccent.withOpacity(0.35),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryAccent.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [AppTheme.primaryAccent, AppTheme.electricViolet],
                            ),
                          ),
                          child: const Icon(Icons.auto_awesome, size: 13, color: Colors.black),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Show Featured Moments',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.06),
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppTheme.primaryAccent,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Section Header: My Albums
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Albums',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    '$totalFolders albums',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.darkTextSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2-Column Apple Photos Albums Grid
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 18,
                childAspectRatio: 0.82,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  // Card 0: "All Photos & Videos"
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

                  // Subsequent cards: Physical phone folders
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
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      ),
    );
  }

  /// Secondary View: Shows media inside the opened folder with 3D tiles & multi-select
  Widget _buildFolderMediaView(
    BackupProvider backup,
    Map<String, List<MediaItem>> groupedFolders,
  ) {
    final List<MediaItem> rawItems;
    if (_openedFolder == 'All Photos & Videos') {
      rawItems = backup.mediaItems;
    } else {
      rawItems = groupedFolders[_openedFolder] ?? [];
    }

    final items = _filterAndSortItems(rawItems);

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.darkCard,
                border: Border.all(color: Colors.white12),
              ),
              child: const Icon(Icons.perm_media_outlined, size: 48, color: Colors.white24),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results matching "$_searchQuery"'
                  : (_activeFilter == MediaFilter.favorites
                      ? 'No favorite items in this album'
                      : 'No media in "$_openedFolder"'),
              style: const TextStyle(
                fontSize: 15,
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
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 90),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _gridColumns,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 1.0,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = _selectedIds.contains(item.localId);

          return MediaItemTile(
            key: ValueKey(item.localId),
            item: item,
            isSelectionMode: _isSelectionMode,
            isSelected: isSelected,
            onLongPress: () {
              if (!_isSelectionMode) {
                _enterSelectionMode(item.localId);
              }
            },
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelection(item.localId);
              } else {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    opaque: false,
                    barrierColor: Colors.black,
                    reverseTransitionDuration: Duration.zero,
                    pageBuilder: (_, _, _) => MediaPreviewScreen(
                      items: items,
                      initialIndex: index,
                    ),
                    transitionsBuilder: (_, animation, _, child) =>
                        FadeTransition(opacity: animation, child: child),
                    transitionDuration: const Duration(milliseconds: 180),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  /// Apple Photos Translucent Bottom Tab Bar
  Widget _buildFloatingBottomNav() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: 8,
            bottom: MediaQuery.of(context).padding.bottom > 0
                ? MediaQuery.of(context).padding.bottom
                : 10,
          ),
          decoration: BoxDecoration(
            color: const Color(0xE6121214),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.12),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAppleTabItem(0, 'Library', CupertinoIcons.photo_on_rectangle, CupertinoIcons.photo_fill_on_rectangle_fill),
              _buildAppleTabItem(1, 'Albums', CupertinoIcons.rectangle_stack, CupertinoIcons.rectangle_stack_fill),
              _buildAppleTabItem(2, 'Favorites', CupertinoIcons.heart, CupertinoIcons.heart_fill),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppleTabItem(int index, String label, IconData unselectedIcon, IconData selectedIcon) {
    final isSelected = _currentTabIndex == index && _openedFolder == null;
    final favCount = FavoritesService.instance.count;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 0,
      onPressed: () {
        setState(() {
          _currentTabIndex = index;
          _openedFolder = null;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                isSelected ? selectedIcon : unselectedIcon,
                size: 23,
                color: isSelected ? AppTheme.appleBlue : AppTheme.darkTextSecondary,
              ),
              if (index == 2 && favCount > 0 && !isSelected)
                Positioned(
                  top: -2,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.roseDanger,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$favCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppTheme.appleBlue : AppTheme.darkTextSecondary,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  /// Apple Photos Translucent Batch Action Bar
  Widget _buildBatchActionBar(List<MediaItem> allItems) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: 10,
            bottom: MediaQuery.of(context).padding.bottom > 0
                ? MediaQuery.of(context).padding.bottom
                : 12,
            left: 28,
            right: 28,
          ),
          decoration: BoxDecoration(
            color: const Color(0xE6121214),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.12),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 0,
                onPressed: () => _batchShareSelected(allItems),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.share, color: AppTheme.appleBlue, size: 23),
                    const SizedBox(height: 2),
                    Text(
                      'Share (${_selectedIds.length})',
                      style: const TextStyle(color: AppTheme.appleBlue, fontSize: 11),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 0,
                onPressed: () => _batchToggleFavorites(allItems),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.heart, color: AppTheme.appleBlue, size: 23),
                    SizedBox(height: 2),
                    Text('Favorite', style: TextStyle(color: AppTheme.appleBlue, fontSize: 11)),
                  ],
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 0,
                onPressed: () => _batchDeleteSelected(allItems),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.trash, color: AppTheme.roseDanger, size: 23),
                    const SizedBox(height: 2),
                    Text(
                      'Delete (${_selectedIds.length})',
                      style: const TextStyle(color: AppTheme.roseDanger, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BackupProvider backup) {
    final hasPerm = MediaScannerService.instance.isPermissionGranted;
    return RefreshIndicator(
      color: AppTheme.primaryAccent,
      backgroundColor: AppTheme.darkCard,
      onRefresh: () => backup.startScan(forceFullScan: false),
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
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.darkCard,
                        border: Border.all(color: Colors.white12),
                        boxShadow: AppTheme.depthShadow(depth: 10),
                      ),
                      child: Icon(
                        backup.isScanning
                            ? Icons.sync
                            : (!hasPerm
                                ? Icons.lock_person_outlined
                                : Icons.photo_library_outlined),
                        size: 54,
                        color: backup.isScanning
                            ? AppTheme.primaryAccent
                            : Colors.white24,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      backup.isScanning
                          ? 'Scanning 3D device albums...'
                          : (!hasPerm
                              ? 'Media Permission Required'
                              : 'No albums found on device'),
                      style: const TextStyle(
                        fontSize: 17,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      backup.isScanning
                          ? 'Indexing device photos and videos into 3D gallery'
                          : (!hasPerm
                              ? 'Please grant photo and video access to allow Gallery to organize your albums in 3D.'
                              : 'Pull down to refresh or tap below to scan device albums'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.55),
                      ),
                    ),
                    if (!backup.isScanning) ...[
                      const SizedBox(height: 24),
                      if (!hasPerm) ...[
                        ElevatedButton.icon(
                          onPressed: () async {
                            await MediaScannerService.instance.requestPermission();
                            await backup.startScan(forceFullScan: true);
                          },
                          icon: const Icon(Icons.security, size: 18),
                          label: const Text('Grant Media Permission'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryAccent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 26,
                              vertical: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () =>
                              MediaScannerService.instance.openSettings(),
                          icon: const Icon(Icons.settings,
                              size: 16, color: Colors.white54),
                          label: const Text('Open App Settings',
                              style: TextStyle(color: Colors.white70)),
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          onPressed: () =>
                              backup.startScan(forceFullScan: false),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Scan Device Media'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryAccent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 26,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ],
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
}
