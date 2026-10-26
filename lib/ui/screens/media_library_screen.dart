import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
          color: const Color(0xFF0C1322),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          boxShadow: AppTheme.depthShadow(depth: 16),
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
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sort Gallery By',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildSortOption(SortMode.newest, 'Newest First', Icons.access_time_rounded),
            _buildSortOption(SortMode.oldest, 'Oldest First', Icons.history_rounded),
            _buildSortOption(SortMode.size, 'File Size (Largest)', Icons.data_usage_rounded),
            _buildSortOption(SortMode.name, 'Name (A to Z)', Icons.sort_by_alpha_rounded),
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
          color: isSelected ? AppTheme.primaryAccent.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppTheme.primaryAccent.withOpacity(0.4), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? AppTheme.primaryAccent : Colors.white54),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryAccent : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppTheme.primaryAccent, size: 18),
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

                // Floating 3D Frosted Glass Navigation Island / Batch Actions Bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.of(context).padding.bottom + 14,
                  child: Center(
                    child: _isSelectionMode
                        ? _buildBatchActionBar(currentMediaPool)
                        : _buildFloatingBottomNav(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Top 3D App Bar: changes to selection toolbar when in batch mode
  Widget _buildTopBar(
    BackupProvider backup,
    List<MediaItem> currentPool,
    Map<String, List<MediaItem>> groupedFolders,
    FavoritesService favService,
  ) {
    if (_isSelectionMode) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8),
          ],
        ),
        child: Row(
          children: [
            _buildTopCircleAction(
              icon: Icons.close_rounded,
              tooltip: 'Cancel selection',
              onTap: _exitSelectionMode,
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primaryAccent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryAccent.withOpacity(0.6), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryAccent.withOpacity(0.25),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                '${_selectedIds.length} Selected',
                style: GoogleFonts.outfit(
                  color: AppTheme.primaryAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _selectAll(currentPool),
              icon: const Icon(Icons.select_all_rounded, size: 18, color: Colors.white70),
              label: Text(
                _selectedIds.length == currentPool.length ? 'Deselect All' : 'Select All',
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    String titleText = 'Gallery';
    String subtitleText = '${backup.mediaItems.length} photos & videos';

    if (_openedFolder != null) {
      titleText = _openedFolder!;
      subtitleText = '${_filterAndSortItems(currentPool).length} items';
    } else if (_currentTabIndex == 1) {
      titleText = 'Albums';
      subtitleText = '${groupedFolders.keys.length} collections';
    } else if (_currentTabIndex == 2) {
      titleText = 'Favorites';
      subtitleText = '${favService.count} starred highlights';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppTheme.darkBg,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          // Back button if folder opened
          if (_openedFolder != null) ...[
            _buildTopCircleAction(
              icon: Icons.arrow_back,
              tooltip: 'Back to Albums',
              onTap: () => setState(() => _openedFolder = null),
            ),
            const SizedBox(width: 10),
          ] else ...[
            // Brand mark: Official App Logo (same as launcher icon)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/icons/app_logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryAccent,
                        AppTheme.electricViolet,
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    size: 18,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],

          // Title with holographic shader
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.holographicGradient.createShader(bounds),
                  child: Text(
                    titleText,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  subtitleText,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.55),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),

          // Density Switcher (2 -> 3 -> 4 columns)
          if (_currentTabIndex != 1 || _openedFolder != null)
            _buildTopCircleAction(
              icon: _gridColumns == 2
                  ? Icons.grid_view_rounded
                  : (_gridColumns == 3
                      ? Icons.view_comfy_alt_rounded
                      : Icons.view_compact_rounded),
              tooltip: 'Grid Density (${_gridColumns}x)',
              onTap: () {
                setState(() {
                  _gridColumns = _gridColumns == 2 ? 3 : (_gridColumns == 3 ? 4 : 2);
                });
              },
            ),

          // Toggle Featured Moments (when in Albums view)
          if (_openedFolder == null &&
              _currentTabIndex == 1 &&
              backup.mediaItems.isNotEmpty)
            _buildTopCircleAction(
              icon: _showFeaturedShowcase
                  ? Icons.auto_awesome
                  : Icons.auto_awesome_outlined,
              tooltip: _showFeaturedShowcase
                  ? 'Hide Featured Moments'
                  : 'Show Featured Moments',
              isActive: _showFeaturedShowcase,
              onTap: () => _toggleFeaturedMoments(!_showFeaturedShowcase),
            ),

          // Search Button
          _buildTopCircleAction(
            icon: _isSearchOpen ? Icons.search_off_rounded : Icons.search_rounded,
            tooltip: 'Search media',
            isActive: _isSearchOpen,
            onTap: () {
              setState(() {
                _isSearchOpen = !_isSearchOpen;
                if (!_isSearchOpen) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),

          // Sort Button
          _buildTopCircleAction(
            icon: Icons.tune_rounded,
            tooltip: 'Sort Options',
            onTap: _showSortOptionsDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildTopCircleAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isActive = false,
    Color? activeColor,
  }) {
    final effectiveColor = activeColor ?? AppTheme.primaryAccent;
    return Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.only(left: 6),
      decoration: BoxDecoration(
        color: isActive ? effectiveColor.withOpacity(0.18) : AppTheme.darkCard,
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive
              ? effectiveColor.withOpacity(0.6)
              : Colors.white.withOpacity(0.1),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
          if (isActive)
            BoxShadow(
              color: effectiveColor.withOpacity(0.3),
              blurRadius: 8,
            ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 18),
        color: isActive ? effectiveColor : Colors.white70,
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }

  /// Animated 3D Search Input Bar
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryAccent.withOpacity(0.4), width: 1.2),
        boxShadow: AppTheme.depthShadow(depth: 8, glowColor: AppTheme.primaryAccent, glowOpacity: 0.15),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppTheme.primaryAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search photos, videos, albums...',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            ),
        ],
      ),
    );
  }

  /// Horizontally scrollable 3D Category Pill Strip
  Widget _buildCategoryPillStrip(FavoritesService favService) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          _buildFilterChip('All', Icons.grid_view_rounded, MediaFilter.all),
          _buildFilterChip('Photos', Icons.photo_outlined, MediaFilter.photos),
          _buildFilterChip('Videos', Icons.videocam_outlined, MediaFilter.videos),
          _buildFilterChip(
            'Favorites (${favService.count})',
            Icons.favorite_rounded,
            MediaFilter.favorites,
            activeColor: AppTheme.roseDanger,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    IconData icon,
    MediaFilter filter, {
    Color activeColor = AppTheme.primaryAccent,
  }) {
    final isSelected = _activeFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() => _activeFilter = filter);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.18) : AppTheme.darkCard,
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    activeColor.withOpacity(0.24),
                    activeColor.withOpacity(0.10),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? activeColor : Colors.white.withOpacity(0.1),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
            if (isSelected)
              BoxShadow(
                color: activeColor.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? activeColor : Colors.white60,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white70,
                letterSpacing: 0.1,
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
            // Flagship Date Section Header with Day Select Button
            SliverToBoxAdapter(
              child: Builder(
                builder: (context) {
                  final isGroupSelected = entry.value.isNotEmpty &&
                      entry.value.every((it) => _selectedIds.contains(it.localId));

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${entry.value.length} ${entry.value.length == 1 ? 'item' : 'items'}',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.55),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => _toggleSelectDateGroup(entry.value),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isGroupSelected
                                  ? AppTheme.primaryAccent.withOpacity(0.18)
                                  : Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isGroupSelected
                                    ? AppTheme.primaryAccent.withOpacity(0.6)
                                    : Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isGroupSelected
                                      ? Icons.check_circle_rounded
                                      : Icons.check_circle_outline_rounded,
                                  size: 13,
                                  color: isGroupSelected
                                      ? AppTheme.primaryAccent
                                      : Colors.white60,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isGroupSelected ? 'Selected' : 'Select',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isGroupSelected
                                        ? AppTheme.primaryAccent
                                        : Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Responsive Media Grid
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _gridColumns,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: _gridColumns == 2 ? 0.9 : (_gridColumns == 3 ? 0.82 : 0.78),
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
                              barrierColor: Colors.black.withOpacity(0.01),
                              reverseTransitionDuration: Duration.zero,
                              pageBuilder: (_, _, _) => MediaPreviewScreen(
                                items: filtered,
                                initialIndex: globalIndex != -1 ? globalIndex : 0,
                              ),
                              transitionsBuilder: (_, animation, _, child) =>
                                  FadeTransition(opacity: animation, child: child),
                              transitionDuration: const Duration(milliseconds: 220),
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
          // Bottom spacer for floating island
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
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

          // Section Header: Albums & Stats
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.folder_copy_rounded,
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
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.55),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2-Column 3D Stack Albums Grid
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 16,
                childAspectRatio: 0.86,
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
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 100),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _gridColumns,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: _gridColumns == 2 ? 0.9 : (_gridColumns == 3 ? 0.82 : 0.78),
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
                    barrierColor: Colors.black.withOpacity(0.01),
                    reverseTransitionDuration: Duration.zero,
                    pageBuilder: (_, _, _) => MediaPreviewScreen(
                      items: items,
                      initialIndex: index,
                    ),
                    transitionsBuilder: (_, animation, _, child) =>
                        FadeTransition(opacity: animation, child: child),
                    transitionDuration: const Duration(milliseconds: 220),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  /// Floating Frosted Glass Bottom Navigation Island (VisionOS / Dynamic Island)
  Widget _buildFloatingBottomNav() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xE00A1020),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(
              color: Colors.white.withOpacity(0.16),
              width: 1.0,
            ),
            boxShadow: AppTheme.depthShadow(
              depth: 16,
              glowColor: AppTheme.primaryAccent,
              glowOpacity: 0.15,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildNavTab(0, 'Photos', Icons.photo_library_outlined, Icons.photo_library_rounded),
              const SizedBox(width: 6),
              _buildNavTab(1, 'Albums', Icons.folder_copy_outlined, Icons.folder_copy_rounded),
              const SizedBox(width: 6),
              _buildNavTab(2, 'Favorites', Icons.favorite_border_rounded, Icons.favorite_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavTab(int index, String label, IconData unselectedIcon, IconData selectedIcon) {
    final isSelected = _currentTabIndex == index && _openedFolder == null;
    final favCount = FavoritesService.instance.count;

    return InkWell(
      onTap: () {
        setState(() {
          _currentTabIndex = index;
          _openedFolder = null;
        });
      },
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryAccent.withOpacity(0.18) : Colors.transparent,
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppTheme.primaryAccent.withOpacity(0.24),
                    AppTheme.electricViolet.withOpacity(0.14),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(24),
          border: isSelected
              ? Border.all(color: AppTheme.primaryAccent.withOpacity(0.55), width: 1.2)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryAccent.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              size: 19,
              color: isSelected ? AppTheme.primaryAccent : Colors.white60,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
            ],
            // Badge for favorites count
            if (index == 2 && favCount > 0 && !isSelected) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppTheme.roseDanger,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$favCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Floating 3D Frosted Glass Batch Action Bar
  Widget _buildBatchActionBar(List<MediaItem> allItems) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.92),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.14), width: 1.2),
            boxShadow: AppTheme.depthShadow(
              depth: 14,
              glowColor: AppTheme.primaryAccent,
              glowOpacity: 0.18,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBatchButton(
                icon: Icons.share_rounded,
                label: 'Share (${_selectedIds.length})',
                onTap: () => _batchShareSelected(allItems),
              ),
              const SizedBox(width: 8),
              _buildBatchButton(
                icon: Icons.favorite_border_rounded,
                label: 'Favorite',
                onTap: () => _batchToggleFavorites(allItems),
              ),
              const SizedBox(width: 8),
              _buildBatchButton(
                icon: Icons.delete_sweep_rounded,
                label: 'Delete (${_selectedIds.length})',
                color: AppTheme.roseDanger,
                onTap: () => _batchDeleteSelected(allItems),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBatchButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
