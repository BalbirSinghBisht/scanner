import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../providers/backup_provider.dart';
import '../../services/database_helper.dart';
import '../../services/folder_service.dart';
import '../../services/vault_service.dart';
import '../widgets/haikei_background.dart';
import '../widgets/media_item_tile.dart';
import '../widgets/pin_code_dialog.dart';
import 'media_preview_screen.dart';

class PrivateFolderScreen extends StatefulWidget {
  const PrivateFolderScreen({super.key});

  @override
  State<PrivateFolderScreen> createState() => _PrivateFolderScreenState();
}

class _PrivateFolderScreenState extends State<PrivateFolderScreen>
    with WidgetsBindingObserver {
  final VaultService _vault = VaultService.instance;
  List<MediaItem> _privateItems = [];
  bool _isLoading = true;

  // Multi-selection state
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  // View density: 2, 3, 4
  final int _gridColumns = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrivateItems();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Auto-lock vault when leaving the screen
    _vault.lock();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      // Re-lock immediately if user leaves app
      _vault.lock();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _loadPrivateItems() async {
    setState(() => _isLoading = true);
    final items = await _vault.getPrivateItems();
    if (mounted) {
      setState(() {
        _privateItems = items;
        _isLoading = false;
      });
    }
  }

  void _lockAndExit() {
    _vault.lock();
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  void _toggleSelection(String localId) {
    HapticFeedback.selectionClick();
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

  void _selectAll() {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedIds.addAll(_privateItems.map((e) => e.localId));
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _moveSelectedOutOfVault() async {
    if (_selectedIds.isEmpty) return;

    final selectedItems =
        _privateItems.where((it) => _selectedIds.contains(it.localId)).toList();

    // Show album selection dialog
    final folders = await FolderService.instance.getAllAlbums();
    if (!mounted) return;

    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Restore from Private Folder'),
        message: Text(
          selectedItems.length == 1
              ? 'Restore item to its original location or choose an album'
              : 'Restore ${selectedItems.length} items to their original location or choose an album',
        ),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop('__RESTORE_ORIGINAL__'),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.arrow_counterclockwise, size: 18),
                SizedBox(width: 8),
                Text('Restore to Same Place (Original)'),
              ],
            ),
          ),
          ...folders.map((f) {
            return CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(f),
              child: Text(f),
            );
          }),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(ctx).pop(null),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (action == null || !mounted) return;

    final backup = context.read<BackupProvider>();
    final isOriginal = action == '__RESTORE_ORIGINAL__';
    final targetFolder = isOriginal ? null : action;

    await _vault.moveOutOfVault(selectedItems, targetFolder);
    await backup.refreshData();

    _exitSelectionMode();
    await _loadPrivateItems();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isOriginal
                ? 'Restored ${selectedItems.length} item(s) to original location'
                : 'Moved ${selectedItems.length} item(s) to $action',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteSelectedPermanently() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Items?'),
        content: Text(
          'Are you sure you want to permanently delete ${_selectedIds.length} item(s) from Private Folder?',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final selectedItems =
        _privateItems.where((it) => _selectedIds.contains(it.localId)).toList();

    for (final it in selectedItems) {
      if (it.localFilePath != null && it.localFilePath!.isNotEmpty) {
        try {
          final f = File(it.localFilePath!);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
    }

    await DatabaseHelper.instance.deleteMediaItems(_selectedIds.toList());
    if (!mounted) return;
    final backup = context.read<BackupProvider>();
    await backup.refreshData();

    _exitSelectionMode();
    await _loadPrivateItems();
  }

  Future<void> _showAddItemsPicker() async {
    final backup = context.read<BackupProvider>();
    final visibleItems = backup.mediaItems.where((it) => !it.isLockedFolder).toList();

    if (visibleItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No photos or videos available to lock.')),
      );
      return;
    }

    final chosenIds = <String>{};

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final c = AppTheme.colors(ctx);
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: c.surfaceElevated,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: c.glassBorder, width: 0.6),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.textTertiary.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add to Private Folder',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          color: c.primary,
                          disabledColor: c.isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          onPressed: chosenIds.isEmpty
                              ? null
                              : () => Navigator.of(context).pop(true),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.lock_fill,
                                size: 13,
                                color: chosenIds.isEmpty ? c.textTertiary : Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                chosenIds.isEmpty ? 'Lock' : 'Lock (${chosenIds.length})',
                                style: TextStyle(
                                  color: chosenIds.isEmpty ? c.textTertiary : Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                      ),
                      itemCount: visibleItems.length,
                      itemBuilder: (context, index) {
                        final item = visibleItems[index];
                        final isSelected = chosenIds.contains(item.localId);
                        return GestureDetector(
                          onTap: () {
                            setSheetState(() {
                              if (isSelected) {
                                chosenIds.remove(item.localId);
                              } else {
                                chosenIds.add(item.localId);
                              }
                            });
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              MediaItemTile(item: item),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                color: isSelected
                                    ? c.primary.withOpacity(0.35)
                                    : Colors.transparent,
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? c.primary : Colors.black38,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == true && chosenIds.isNotEmpty && mounted) {
      final itemsToLock =
          visibleItems.where((it) => chosenIds.contains(it.localId)).toList();
      await _vault.moveToVault(itemsToLock);
      await backup.refreshData();
      await _loadPrivateItems();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Locked ${itemsToLock.length} item(s) in Private Folder'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: HaikeiBackground()),

          SafeArea(
            child: Column(
              children: [
                // Top App Bar
                _buildTopBar(c),

                // Main Content
                Expanded(
                  child: _isLoading
                      ? const Center(child: CupertinoActivityIndicator())
                      : _privateItems.isEmpty
                          ? _buildEmptyState(c)
                          : _buildGridView(c),
                ),
              ],
            ),
          ),

          // Bottom Action Bar when in multi-selection mode
          if (_isSelectionMode)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _buildBatchActionBar(c),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(AppThemeColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 36,
            onPressed: _lockAndExit,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.chevron_back, color: c.primary, size: 22),
                const SizedBox(width: 4),
                Text(
                  'Albums',
                  style: TextStyle(
                    color: c.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5A93B).withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.lock_shield_fill,
                    color: Color(0xFFE5A93B),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Private Folder',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          // Actions
          if (_isSelectionMode)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _exitSelectionMode,
              child: Text(
                'Done',
                style: TextStyle(
                  color: c.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            )
          else ...[
            CupertinoButton(
              padding: const EdgeInsets.all(8),
              minSize: 36,
              onPressed: _showAddItemsPicker,
              child: Icon(CupertinoIcons.plus, color: c.primary, size: 21),
            ),
            PopupMenuButton<String>(
              icon: Icon(CupertinoIcons.ellipsis_circle, color: c.primary, size: 21),
              color: c.surfaceElevated,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (val) async {
                if (val == 'lock') {
                  _lockAndExit();
                } else if (val == 'change_pin') {
                  final changed = await PinCodeDialog.showChange(context);
                  if (changed && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PIN successfully updated.')),
                    );
                  }
                } else if (val == 'select') {
                  setState(() => _isSelectionMode = true);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'select',
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.checkmark_circle, size: 18),
                      SizedBox(width: 10),
                      Text('Select Items'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'change_pin',
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.lock_rotation, size: 18),
                      SizedBox(width: 10),
                      Text('Change PIN'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'lock',
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.lock_fill, size: 18),
                      SizedBox(width: 10),
                      Text('Lock Now'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppThemeColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFE5A93B).withOpacity(0.8),
                    const Color(0xFFDF6B2A).withOpacity(0.8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE5A93B).withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.lock_shield_fill,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Private Folder is Empty',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Photos and videos placed here are hidden from your main library and protected by your PIN. They are also securely synced to Google Drive in your private backup.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: c.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              color: c.primary,
              borderRadius: BorderRadius.circular(22),
              onPressed: _showAddItemsPicker,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.plus, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Add Photos & Videos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridView(AppThemeColors c) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 110),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _gridColumns,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = _privateItems[index];
                final isSelected = _selectedIds.contains(item.localId);

                return GestureDetector(
                  onTap: () {
                    if (_isSelectionMode) {
                      _toggleSelection(item.localId);
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => MediaPreviewScreen(
                            items: _privateItems,
                            initialIndex: index,
                          ),
                        ),
                      ).then((_) => _loadPrivateItems());
                    }
                  },
                  onLongPress: () {
                    if (!_isSelectionMode) {
                      setState(() {
                        _isSelectionMode = true;
                        _selectedIds.add(item.localId);
                      });
                      HapticFeedback.heavyImpact();
                    }
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MediaItemTile(item: item),

                      if (_isSelectionMode) ...[
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          color: isSelected
                              ? c.primary.withOpacity(0.3)
                              : Colors.black26,
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? c.primary : Colors.black45,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 15, color: Colors.white)
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
              childCount: _privateItems.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBatchActionBar(AppThemeColors c) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: AppTheme.floatingNavbarDecoration(context: context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minSize: 0,
                onPressed: _selectAll,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.checkmark_seal, color: c.primary, size: 20),
                    const SizedBox(height: 3),
                    Text('Select All',
                        style: TextStyle(color: c.primary, fontSize: 11, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minSize: 0,
                onPressed: _moveSelectedOutOfVault,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.arrow_counterclockwise, color: c.primary, size: 20),
                    const SizedBox(height: 3),
                    Text('Restore',
                        style: TextStyle(color: c.primary, fontSize: 11, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minSize: 0,
                onPressed: _deleteSelectedPermanently,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.trash, color: c.accentRose, size: 20),
                    const SizedBox(height: 3),
                    Text('Delete',
                        style: TextStyle(color: c.accentRose, fontSize: 11, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
