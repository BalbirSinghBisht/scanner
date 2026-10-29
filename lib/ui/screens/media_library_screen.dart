import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../providers/backup_provider.dart';
import '../../services/device_settings_helper.dart';
import '../../services/favorites_service.dart';
import '../../services/media_scanner_service.dart';
import '../widgets/haikei_background.dart';
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
      final itemDate =
          DateTime(item.createdAt.year, item.createdAt.month, item.createdAt.day);
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
        result =
            result.where((it) => it.mediaType == AppMediaType.image).toList();
        break;
      case MediaFilter.videos:
        result =
            result.where((it) => it.mediaType == AppMediaType.video).toList();
        break;
      case MediaFilter.favorites:
        final favService = FavoritesService.instance;
        result = result.where((it) => favService.isFavorite(it.localId)).toList();
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
        result.sort((a, b) =>
            a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()));
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
    final allInGroupSelected =
        items.every((it) => _selectedIds.contains(it.localId));
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
    final selectedItems =
        allItems.where((it) => _selectedIds.contains(it.localId)).toList();
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
        await DeviceSettingsHelper.shareMediaFile(
            filePaths.first, selectedItems.first.mimeType);
      } else {
        await DeviceSettingsHelper.shareMultipleMediaFiles(filePaths);
      }
    } else {
      if (mounted) {
        final c = AppTheme.colors(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Selected files could not be accessed'),
            backgroundColor: c.accentRose,
          ),
        );
      }
    }
  }

  Future<void> _batchDeleteSelected(List<MediaItem> allItems) async {
    final c = AppTheme.colors(context);
    final selectedItems =
        allItems.where((it) => _selectedIds.contains(it.localId)).toList();
    if (selectedItems.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: AlertDialog(
          backgroundColor: c.surfaceGlass,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: c.glassBorder, width: 0.8),
          ),
          title: Row(
            children: [
              Icon(Icons.delete_sweep_rounded, color: c.accentRose, size: 24),
              const SizedBox(width: 10),
              Text(
                'Delete ${selectedItems.length} items?',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete these ${selectedItems.length} files permanently from your device storage?',
            style: TextStyle(color: c.textSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accentRose,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete Permanently'),
            ),
          ],
        ),
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
            backgroundColor: c.surfaceElevated,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _batchToggleFavorites(List<MediaItem> allItems) async {
    final favService = FavoritesService.instance;
    final selectedItems =
        allItems.where((it) => _selectedIds.contains(it.localId)).toList();
    if (selectedItems.isEmpty) return;

    final allFavorited =
        selectedItems.every((it) => favService.isFavorite(it.localId));
    for (final it in selectedItems) {
      await favService.setFavorite(it.localId, !allFavorited);
    }
    setState(() {});
  }

  void _showSortOptionsDialog() {
    final c = AppTheme.colors(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            decoration: BoxDecoration(
              color: c.surfaceGlassFloating,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: c.glassBorder, width: 0.6),
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
                    width: 38,
                    height: 5,
                    decoration: BoxDecoration(
                      color: c.textTertiary.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sort Gallery',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSortOption(
                    SortMode.newest, 'Newest First', CupertinoIcons.clock, c),
                _buildSortOption(
                    SortMode.oldest, 'Oldest First', CupertinoIcons.time, c),
                _buildSortOption(SortMode.size, 'File Size (Largest)',
                    CupertinoIcons.square_stack_3d_up, c),
                _buildSortOption(SortMode.name, 'Name (A to Z)',
                    CupertinoIcons.textformat_abc, c),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortOption(
      SortMode mode, String label, IconData icon, AppThemeColors c) {
    final isSelected = _sortMode == mode;
    return InkWell(
      onTap: () {
        setState(() => _sortMode = mode);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? c.primary.withOpacity(c.isDark ? 0.20 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(
                  color: c.primary.withOpacity(0.4), width: 0.6)
              : Border.all(color: Colors.transparent, width: 0.6),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: isSelected ? c.primary : c.textSecondary),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? c.primary : c.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 15,
                letterSpacing: -0.2,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(CupertinoIcons.checkmark, color: c.primary, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final backup = context.watch<BackupProvider>();
    final favService = FavoritesService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final systemUiOverlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlay,
      child: ListenableBuilder(
        listenable: favService,
        builder: (context, _) {
          final groupedFolders = _groupItemsByFolder(backup.mediaItems);
          final sortedFolderNames = groupedFolders.keys.toList()
            ..sort((a, b) =>
                groupedFolders[b]!.length.compareTo(groupedFolders[a]!.length));

          // Reset opened folder if it was removed
          if (_openedFolder != null &&
              _openedFolder != 'All Photos & Videos' &&
              !groupedFolders.containsKey(_openedFolder)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted &&
                  _openedFolder != null &&
                  !groupedFolders.containsKey(_openedFolder)) {
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
            canPop: _openedFolder == null &&
                !_isSelectionMode &&
                !_isSearchOpen &&
                _currentTabIndex == 0,
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
              backgroundColor: c.bg,
              body: Stack(
                children: [
                  // Haikei-inspired Animated Organic Fluid Background
                  const Positioned.fill(
                    child: HaikeiBackground(),
                  ),

                  // Main Content View
                  SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        // Top Frosted Glass App Bar / Selection Header
                        _buildTopBar(
                            backup, currentMediaPool, groupedFolders, favService, c),

                        // Fixed 2px scanning progress indicator
                        SizedBox(
                          height: 2,
                          child: backup.isScanning && backup.mediaItems.isNotEmpty
                              ? LinearProgressIndicator(
                                  minHeight: 2,
                                  backgroundColor: Colors.transparent,
                                  color: c.primary,
                                )
                              : const SizedBox.shrink(),
                        ),

                        // Animated Search Bar
                        if (_isSearchOpen) _buildSearchBar(c),

                        // Motion Primitives Category Filter Strip
                        if (_openedFolder != null || _currentTabIndex != 1)
                          _buildCategoryPillStrip(favService, c),

                        // Main Content Body
                        Expanded(
                          child: _buildCurrentTabContent(
                            backup,
                            groupedFolders,
                            sortedFolderNames,
                            currentMediaPool,
                            c,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Motion Primitives Floating Rounded Bottom Navigation / Batch Bar
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(context).padding.bottom > 0
                        ? MediaQuery.of(context).padding.bottom + 4
                        : 16,
                    child: _isSelectionMode
                        ? _buildBatchActionBar(currentMediaPool, c)
                        : _buildFloatingBottomNav(c),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 3D Glassmorphic Top Bar with Realtime Colors & Specular Light Sheen
  Widget _buildTopBar(
    BackupProvider backup,
    List<MediaItem> currentPool,
    Map<String, List<MediaItem>> groupedFolders,
    FavoritesService favService,
    AppThemeColors c,
  ) {
    if (_isSelectionMode) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: AppTheme.appleBlurBar(context: context),
            child: Row(
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: _exitSelectionMode,
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: c.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${_selectedIds.length} Selected',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.textPrimary,
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
                    _selectedIds.length == currentPool.length
                        ? 'Deselect All'
                        : 'Select All',
                    style: TextStyle(
                      color: c.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
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

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          decoration: AppTheme.appleBlurBar(context: context),
          child: Row(
            children: [
              // Back button if folder opened
              if (_openedFolder != null) ...[
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: () => setState(() => _openedFolder = null),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.chevron_back,
                          color: c.primary, size: 26),
                      Text('Albums',
                          style: TextStyle(color: c.primary, fontSize: 16)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Title in Bold Realtime Colors Typography
              Expanded(
                child: Text(
                  titleText,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Search Button with 3D Glass Pill
              CupertinoButton(
                padding: const EdgeInsets.all(5),
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
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isSearchOpen
                        ? c.primary.withOpacity(0.18)
                        : (c.isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.black.withOpacity(0.04)),
                    shape: BoxShape.circle,
                    border: Border.all(color: c.glassBorder, width: 0.6),
                  ),
                  child: Icon(
                    _isSearchOpen
                        ? CupertinoIcons.clear
                        : CupertinoIcons.search,
                    color: _isSearchOpen ? c.primary : c.textSecondary,
                    size: 19,
                  ),
                ),
              ),

              // Density Switcher
              if (_currentTabIndex != 1 || _openedFolder != null)
                CupertinoButton(
                  padding: const EdgeInsets.all(5),
                  minSize: 0,
                  onPressed: () {
                    setState(() {
                      _gridColumns = _gridColumns == 2
                          ? 3
                          : (_gridColumns == 3 ? 4 : 2);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: c.isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.black.withOpacity(0.04),
                      shape: BoxShape.circle,
                      border: Border.all(color: c.glassBorder, width: 0.6),
                    ),
                    child: Icon(
                      _gridColumns == 2
                          ? CupertinoIcons.square_grid_2x2
                          : (_gridColumns == 3
                              ? CupertinoIcons.rectangle_grid_3x2
                              : CupertinoIcons.circle_grid_hex),
                      color: c.primary,
                      size: 19,
                    ),
                  ),
                ),

              // Sort Options Button
              CupertinoButton(
                padding: const EdgeInsets.all(5),
                minSize: 0,
                onPressed: _showSortOptionsDialog,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.04),
                    shape: BoxShape.circle,
                    border: Border.all(color: c.glassBorder, width: 0.6),
                  ),
                  child: Icon(
                    CupertinoIcons.arrow_up_arrow_down,
                    color: c.primary,
                    size: 18,
                  ),
                ),
              ),

              // Select Button Pill
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                minSize: 0,
                onPressed: () {
                  setState(() => _isSelectionMode = true);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: c.primary.withOpacity(c.isDark ? 0.16 : 0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: c.primary.withOpacity(0.35),
                      width: 0.6,
                    ),
                  ),
                  child: Text(
                    'Select',
                    style: TextStyle(
                      color: c.primary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Liquidmorphic Animated Search Bar
  Widget _buildSearchBar(AppThemeColors c) {
    return AnimatedContainer(
      duration: AppTheme.motionFast,
      curve: AppTheme.liquidSnap,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: AppTheme.liquidInputDecoration(
        context: context,
        borderRadius: 18,
        isFocused: _searchQuery.isNotEmpty,
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.search, color: c.textSecondary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: c.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search photos, videos, albums',
                hintStyle: TextStyle(color: c.textSecondary, fontSize: 15),
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
              child: Icon(CupertinoIcons.clear_circled_solid,
                  color: c.textSecondary, size: 18),
            ),
        ],
      ),
    );
  }

  /// Motion Primitives Category Filter Strip with Dynamic Realtime Colors
  Widget _buildCategoryPillStrip(FavoritesService favService, AppThemeColors c) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          _buildFilterChip('All', CupertinoIcons.square_grid_2x2,
              MediaFilter.all, c),
          _buildFilterChip('Photos', CupertinoIcons.photo,
              MediaFilter.photos, c),
          _buildFilterChip('Videos', CupertinoIcons.videocam,
              MediaFilter.videos, c),
          _buildFilterChip(
            'Favorites (${favService.count})',
            CupertinoIcons.heart_fill,
            MediaFilter.favorites,
            c,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    IconData icon,
    MediaFilter filter,
    AppThemeColors c,
  ) {
    final isSelected = _activeFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() => _activeFilter = filter);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: AppTheme.liquidSnap,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? c.primary : c.surfaceGlass,
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    c.primaryLight,
                    c.primary,
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? c.glassBorderSpecular
                : c.glassBorder,
            width: 0.7,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: c.primary.withOpacity(0.40),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(c.isDark ? 0.20 : 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : c.textSecondary,
            ),
            const SizedBox(width: 5.5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : c.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
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
    AppThemeColors c,
  ) {
    if (_openedFolder != null) {
      return _buildFolderMediaView(backup, groupedFolders, c);
    }

    switch (_currentTabIndex) {
      case 1:
        // Albums Tab (3D Stacks + Featured Moments)
        return _buildFoldersView(backup, groupedFolders, sortedFolderNames, c);
      case 2:
        // Favorites Tab
        return _buildTimelineView(backup, currentPool, c,
            emptyMessage: 'No favorite items yet');
      case 0:
      default:
        // Photos Timeline Tab
        return _buildTimelineView(backup, currentPool, c,
            emptyMessage: 'No photos or videos');
    }
  }

  /// Flagship Timeline Photostream with Sticky Date Section Headers
  Widget _buildTimelineView(
    BackupProvider backup,
    List<MediaItem> rawItems,
    AppThemeColors c, {
    String emptyMessage = 'No media found',
  }) {
    final filtered = _filterAndSortItems(rawItems);

    if (filtered.isEmpty) {
      if (backup.mediaItems.isEmpty) {
        return _buildEmptyState(backup, c);
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.surfaceGlass,
                border: Border.all(color: c.glassBorder),
              ),
              child: Icon(Icons.photo_library_outlined,
                  size: 44, color: c.textTertiary),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results for "$_searchQuery"'
                  : emptyMessage,
              style: TextStyle(
                  fontSize: 15,
                  color: c.textSecondary,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    final dateGroups = _groupByDate(filtered);

    return RefreshIndicator(
      color: c.primary,
      backgroundColor: c.surfaceElevated,
      onRefresh: () => backup.startScan(forceFullScan: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          for (final entry in dateGroups.entries) ...[
            // Date Section Header
            SliverToBoxAdapter(
              child: Builder(
                builder: (context) {
                  final isGroupSelected = entry.value.isNotEmpty &&
                      entry.value
                          .every((it) => _selectedIds.contains(it.localId));

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${entry.value.length}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: c.textSecondary,
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
                              style: TextStyle(
                                fontSize: 14,
                                color: c.primary,
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

            // Photo Grid (Square 1:1, 2px spacing)
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
                                initialIndex:
                                    globalIndex != -1 ? globalIndex : 0,
                              ),
                              transitionsBuilder: (_, animation, _, child) =>
                                  FadeTransition(
                                      opacity: animation, child: child),
                              transitionDuration:
                                  const Duration(milliseconds: 180),
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

          // Library Status Footer
          SliverToBoxAdapter(
            child: _buildLibraryStatusFooter(backup, rawItems, c),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryStatusFooter(
      BackupProvider backup, List<MediaItem> allItems, AppThemeColors c) {
    final photoCount =
        allItems.where((i) => i.mediaType == AppMediaType.image).length;
    final videoCount =
        allItems.where((i) => i.mediaType == AppMediaType.video).length;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$photoCount Photos, $videoCount Videos',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 105), // Room for floating bottom nav
        ],
      ),
    );
  }

  /// Primary View: Shows 3D Showcase Carousel + Albums as 3D stacked cards
  Widget _buildFoldersView(
    BackupProvider backup,
    Map<String, List<MediaItem>> groupedFolders,
    List<String> sortedFolderNames,
    AppThemeColors c,
  ) {
    if (backup.mediaItems.isEmpty) {
      return _buildEmptyState(backup, c);
    }

    final totalCount = backup.mediaItems.length;
    final totalFolders = sortedFolderNames.length;

    return RefreshIndicator(
      color: c.primary,
      backgroundColor: c.surfaceElevated,
      onRefresh: () => backup.startScan(forceFullScan: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // 3D Featured Showcase Carousel
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: c.surfaceGlass,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: c.glassBorder,
                        width: 0.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: c.primary.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [c.primary, c.secondary],
                            ),
                          ),
                          child: const Icon(Icons.auto_awesome,
                              size: 13, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Show Featured Moments',
                          style: TextStyle(
                            color: c.textPrimary,
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
                            color: c.isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.black.withOpacity(0.04),
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: c.primary,
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
                  Text(
                    'My Albums',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    '$totalFolders albums',
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2-Column Albums Grid
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
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
          const SliverToBoxAdapter(child: SizedBox(height: 105)),
        ],
      ),
    );
  }

  /// Secondary View: Shows media inside the opened folder with 3D tiles & multi-select
  Widget _buildFolderMediaView(
    BackupProvider backup,
    Map<String, List<MediaItem>> groupedFolders,
    AppThemeColors c,
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
                color: c.surfaceGlass,
                border: Border.all(color: c.glassBorder),
              ),
              child: Icon(Icons.perm_media_outlined,
                  size: 48, color: c.textTertiary),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results matching "$_searchQuery"'
                  : (_activeFilter == MediaFilter.favorites
                      ? 'No favorite items in this album'
                      : 'No media in "$_openedFolder"'),
              style: TextStyle(
                fontSize: 15,
                color: c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: c.primary,
      backgroundColor: c.surfaceElevated,
      onRefresh: () => backup.startScan(forceFullScan: true),
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 110),
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

  /// Motion Primitives 3D Translucent Floating Bottom Navbar
  /// Features a sliding spring indicator capsule under the active tab!
  Widget _buildFloatingBottomNav(AppThemeColors c) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: AppTheme.floatingNavbarDecoration(context: context),
          child: Stack(
            children: [
              // Specular top light rim
              Positioned(
                top: 0,
                left: 16,
                right: 16,
                height: 1.5,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withOpacity(c.isDark ? 0.35 : 0.60),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Sliding Spring Pill Indicator
              Positioned.fill(
                child: AnimatedAlign(
                  duration: AppTheme.motionSpring,
                  curve: AppTheme.liquidSpring,
                  alignment: _openedFolder != null
                      ? const Alignment(-3.0, 0.0)
                      : (_currentTabIndex == 0
                          ? const Alignment(-1.0, 0.0)
                          : (_currentTabIndex == 1
                              ? const Alignment(0.0, 0.0)
                              : const Alignment(1.0, 0.0))),
                  child: FractionallySizedBox(
                    widthFactor: 1 / 3,
                    heightFactor: 1.0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Container(
                        decoration: BoxDecoration(
                          color: c.isDark
                              ? Colors.white.withOpacity(0.14)
                              : c.primary.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: c.isDark
                                ? Colors.white.withOpacity(0.18)
                                : c.primary.withOpacity(0.25),
                            width: 0.6,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: c.primary.withOpacity(c.isDark ? 0.20 : 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Tab Items
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAppleTabItem(
                    0,
                    'Library',
                    CupertinoIcons.photo_on_rectangle,
                    CupertinoIcons.photo_fill_on_rectangle_fill,
                    c,
                  ),
                  _buildAppleTabItem(
                    1,
                    'Albums',
                    CupertinoIcons.rectangle_stack,
                    CupertinoIcons.rectangle_stack_fill,
                    c,
                  ),
                  _buildAppleTabItem(
                    2,
                    'Favorites',
                    CupertinoIcons.heart,
                    CupertinoIcons.heart_fill,
                    c,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppleTabItem(
    int index,
    String label,
    IconData unselectedIcon,
    IconData selectedIcon,
    AppThemeColors c,
  ) {
    final isSelected = _currentTabIndex == index && _openedFolder == null;
    final favCount = FavoritesService.instance.count;

    return Expanded(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minSize: 0,
        onPressed: () {
          setState(() {
            _currentTabIndex = index;
            _openedFolder = null;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    scale: isSelected ? 1.08 : 1.0,
                    duration: AppTheme.motionFast,
                    curve: AppTheme.springCurve,
                    child: Icon(
                      isSelected ? selectedIcon : unselectedIcon,
                      size: 22,
                      color: isSelected ? c.primary : c.textSecondary,
                    ),
                  ),
                  if (index == 2 && favCount > 0 && !isSelected)
                    Positioned(
                      top: -3,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4.5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: c.accentRose,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: c.accentRose.withOpacity(0.4),
                              blurRadius: 4,
                            ),
                          ],
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
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? c.primary : c.textSecondary,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 3D Translucent Floating Batch Action Bar
  Widget _buildBatchActionBar(List<MediaItem> allItems, AppThemeColors c) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: AppTheme.floatingNavbarDecoration(context: context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minSize: 0,
                onPressed: () => _batchShareSelected(allItems),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.share, color: c.primary, size: 22),
                    const SizedBox(height: 3),
                    Text(
                      'Share (${_selectedIds.length})',
                      style: TextStyle(
                          color: c.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minSize: 0,
                onPressed: () => _batchToggleFavorites(allItems),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.heart, color: c.primary, size: 22),
                    const SizedBox(height: 3),
                    Text('Favorite',
                        style: TextStyle(
                            color: c.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minSize: 0,
                onPressed: () => _batchDeleteSelected(allItems),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.trash, color: c.accentRose, size: 22),
                    const SizedBox(height: 3),
                    Text(
                      'Delete (${_selectedIds.length})',
                      style: TextStyle(
                          color: c.accentRose,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
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

  Widget _buildEmptyState(BackupProvider backup, AppThemeColors c) {
    final hasPerm = MediaScannerService.instance.isPermissionGranted;
    return RefreshIndicator(
      color: c.primary,
      backgroundColor: c.surfaceElevated,
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
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.surfaceGlass,
                        border: Border.all(
                          color: c.glassBorder,
                          width: 0.8,
                        ),
                        boxShadow: AppTheme.depthShadow(
                          depth: 14,
                          glowColor: c.primary,
                          glowOpacity: 0.18,
                        ),
                      ),
                      child: Icon(
                        backup.isScanning
                            ? CupertinoIcons.photo_on_rectangle
                            : (!hasPerm
                                ? CupertinoIcons.lock
                                : CupertinoIcons.photo_on_rectangle),
                        size: 50,
                        color: backup.isScanning ? c.primary : c.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      backup.isScanning
                          ? 'Loading Photos...'
                          : (!hasPerm
                              ? 'Media Permission Required'
                              : 'No Photos or Videos'),
                      style: TextStyle(
                        fontSize: 18,
                        color: c.textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      backup.isScanning
                          ? 'Organizing your photo library'
                          : (!hasPerm
                              ? 'Please grant photo and video access to view your library.'
                              : 'Photos and videos you take will appear here.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: c.textSecondary,
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
                            backgroundColor: c.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 26,
                              vertical: 14,
                            ),
                            elevation: 0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () =>
                              MediaScannerService.instance.openSettings(),
                          icon: Icon(Icons.settings,
                              size: 16, color: c.textSecondary),
                          label: Text('Open App Settings',
                              style: TextStyle(color: c.textSecondary)),
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          onPressed: () =>
                              backup.startScan(forceFullScan: false),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Scan Device Media'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 26,
                              vertical: 14,
                            ),
                            elevation: 0,
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
