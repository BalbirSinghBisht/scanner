import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../providers/backup_provider.dart';
import '../../services/folder_service.dart';
import '../../services/vault_service.dart';
import 'create_album_dialog.dart';
import 'pin_code_dialog.dart';

class MoveToFolderSheet extends StatefulWidget {
  final List<MediaItem> items;

  const MoveToFolderSheet({
    super.key,
    required this.items,
  });

  /// Shows the move sheet and returns destination folder name if moved.
  static Future<String?> show(BuildContext context, List<MediaItem> items) async {
    if (items.isEmpty) return null;
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MoveToFolderSheet(items: items),
    );
  }

  @override
  State<MoveToFolderSheet> createState() => _MoveToFolderSheetState();
}

class _MoveToFolderSheetState extends State<MoveToFolderSheet> {
  List<String> _folders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final list = await FolderService.instance.getAllAlbums();
    if (mounted) {
      setState(() {
        _folders = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleMoveToFolder(String targetFolder) async {
    final backup = context.read<BackupProvider>();
    final success = await FolderService.instance.moveItemsToFolder(
      items: widget.items,
      targetFolderName: targetFolder,
      backupProvider: backup,
    );

    if (mounted && success) {
      Navigator.of(context).pop(targetFolder);
    }
  }

  Future<void> _handleMoveToPrivate() async {
    final isPinConfigured = await VaultService.instance.isPinSet();
    if (!mounted) return;

    if (!isPinConfigured) {
      final pinCreated = await PinCodeDialog.showCreate(context);
      if (!pinCreated || !mounted) return;
    }

    final backup = context.read<BackupProvider>();
    final success = await FolderService.instance.moveItemsToFolder(
      items: widget.items,
      targetFolderName: 'Private (Locked)',
      backupProvider: backup,
    );

    if (mounted && success) {
      Navigator.of(context).pop('Private (Locked)');
    }
  }

  Future<void> _handleCreateNewAlbum() async {
    final newAlbumName = await CreateAlbumDialog.show(context);
    if (newAlbumName != null && newAlbumName.trim().isNotEmpty && mounted) {
      await _handleMoveToFolder(newAlbumName.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final count = widget.items.length;
    final countText = count == 1 ? '1 item' : '$count items';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: c.glassBorder, width: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
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

          // Title bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Move to Album',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      countText,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(CupertinoIcons.xmark_circle_fill,
                      color: c.textTertiary, size: 24),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    children: [
                      // Option 1: Create New Album
                      _buildActionTile(
                        icon: CupertinoIcons.folder_badge_plus,
                        iconColor: c.primary,
                        title: 'New Album',
                        subtitle: 'Create a new album for these items',
                        onTap: _handleCreateNewAlbum,
                        c: c,
                      ),

                      const SizedBox(height: 8),

                      // Option 2: Move to Private Folder (Locked)
                      _buildActionTile(
                        icon: CupertinoIcons.lock_shield_fill,
                        iconColor: const Color(0xFFE5A93B),
                        title: 'Private Folder (Locked)',
                        subtitle: 'Protect with PIN & hide from main library',
                        badge: 'Secure',
                        onTap: _handleMoveToPrivate,
                        c: c,
                      ),

                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Text(
                          'EXISTING ALBUMS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                            color: c.textTertiary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // List of existing albums
                      ..._folders.map((folder) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: InkWell(
                            onTap: () => _handleMoveToFolder(folder),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: c.surfaceGlass,
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: c.glassBorder, width: 0.5),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: c.primary.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getFolderIcon(folder),
                                      size: 18,
                                      color: c.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      folder,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w500,
                                        color: c.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    CupertinoIcons.chevron_right,
                                    size: 16,
                                    color: c.textTertiary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  IconData _getFolderIcon(String folder) {
    final lower = folder.toLowerCase();
    if (lower == 'camera' || lower == 'dcim') return CupertinoIcons.camera;
    if (lower == 'screenshots') return CupertinoIcons.device_phone_portrait;
    if (lower == 'videos' || lower.contains('video')) return CupertinoIcons.videocam;
    return CupertinoIcons.folder;
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? badge,
    required VoidCallback onTap,
    required AppThemeColors c,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.surfaceGlass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.glassBorder, width: 0.6),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: iconColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: c.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

