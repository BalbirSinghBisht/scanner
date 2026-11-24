import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../widgets/cached_thumbnail_image.dart';
import 'media_preview_screen.dart';

class SpaceSaverScreen extends StatefulWidget {
  const SpaceSaverScreen({
    super.key,
    required this.items,
    required this.topClearance,
    required this.onDelete,
  });

  final List<MediaItem> items;
  final double topClearance;
  final Future<bool> Function(MediaItem item) onDelete;

  @override
  State<SpaceSaverScreen> createState() => _SpaceSaverScreenState();
}

class _SpaceSaverScreenState extends State<SpaceSaverScreen> {
  static const _channel = MethodChannel(
    'com.mediabackup.scanner/device_settings',
  );
  List<_StorageVolume> _volumes = const [];
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSpace());
  }

  List<MediaItem> get _duplicates {
    final groups = <String, List<MediaItem>>{};
    for (final item in widget.items) {
      final hash = item.contentHash;
      if (hash != null && hash.isNotEmpty) {
        groups.putIfAbsent(hash, () => []).add(item);
      }
    }
    return [
      for (final group in groups.values)
        if (group.length > 1) ...group.skip(1),
    ];
  }

  List<MediaItem> get _largeVideos =>
      widget.items
          .where((item) => item.isVideo && item.fileSize >= 100 * 1024 * 1024)
          .toList()
        ..sort((a, b) => b.fileSize.compareTo(a.fileSize));

  List<MediaItem> get _similarOrBlurry => widget.items.where((item) {
    if (!item.isImage) return false;
    final pixels = (item.width ?? 0) * (item.height ?? 0);
    return pixels > 0 && pixels < 1000000;
  }).toList()..sort((a, b) => a.fileSize.compareTo(b.fileSize));

  List<MediaItem> get _screenshots =>
      widget.items
          .where((item) => item.isImage && _matchesScreenshot(item))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<MediaItem> get _screenRecordings =>
      widget.items
          .where((item) => item.isVideo && _matchesScreenRecording(item))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  String _searchableMediaText(MediaItem item) =>
      '${item.fileName} ${item.folderName ?? ''} ${item.localFilePath ?? ''}'
          .toLowerCase()
          .replaceAll(RegExp(r'[_\-.]+'), ' ');

  bool _matchesScreenshot(MediaItem item) {
    final text = _searchableMediaText(item);
    return text.contains('screenshot') || text.contains('screen shot');
  }

  bool _matchesScreenRecording(MediaItem item) {
    final text = _searchableMediaText(item);
    return text.contains('screenrecord') ||
        text.contains('screen record') ||
        text.contains('screenrecorder') ||
        text.contains('screen recorder');
  }

  int get _reclaimableBytes {
    final unique = <String, MediaItem>{};
    for (final item in [
      ..._duplicates,
      ..._largeVideos,
      ..._similarOrBlurry,
      ..._screenshots,
      ..._screenRecordings,
    ]) {
      unique[item.localId] = item;
    }
    return unique.values.fold(0, (sum, item) => sum + item.fileSize);
  }

  int get _galleryBytes =>
      widget.items.fold(0, (sum, item) => sum + item.fileSize);

  Future<void> _checkSpace() async {
    setState(() => _checking = true);
    try {
      final stats = await _channel.invokeMapMethod<String, dynamic>(
        'getStorageStats',
      );
      if (!mounted) return;
      setState(() {
        final rawVolumes = stats?['volumes'];
        if (rawVolumes is List) {
          _volumes = rawVolumes
              .whereType<Map>()
              .map(_StorageVolume.fromMap)
              .where((volume) => volume.totalBytes > 0)
              .toList();
        }
        if (_volumes.isEmpty) {
          final total = (stats?['totalBytes'] as num?)?.toInt() ?? 0;
          final free = (stats?['freeBytes'] as num?)?.toInt() ?? 0;
          if (total > 0) {
            _volumes = [
              _StorageVolume(
                name: 'Phone storage',
                rootPath: '',
                totalBytes: total,
                freeBytes: free,
                removable: false,
              ),
            ];
          }
        }
      });
    } on PlatformException {
      // The media analysis remains useful on platforms without native stats.
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  String _size(int bytes) {
    const gb = 1024 * 1024 * 1024;
    const mb = 1024 * 1024;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(0)} MB';
    if (bytes < 1024) return '$bytes B';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    _StorageVolume? phone;
    for (final volume in _volumes) {
      if (!volume.removable) {
        phone = volume;
        break;
      }
    }
    final sdCards = _volumes.where((volume) => volume.removable).toList();
    final used = phone?.usedBytes ?? _galleryBytes;
    final progress = phone != null && phone.totalBytes > 0
        ? (used / phone.totalBytes).clamp(0.0, 1.0)
        : 0.72;
    final phoneSavings = phone == null
        ? _reclaimableBytes
        : _reclaimableForVolume(phone);

    return CustomScrollView(
      key: const PageStorageKey('space_saver_scroll'),
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(18, widget.topClearance + 22, 18, 116),
          sliver: SliverList.list(
            children: [
              Text('STORAGE CHECK', style: _eyebrow(c)),
              const SizedBox(height: 12),
              _storageCard(c, used, phone?.totalBytes, progress, phoneSavings),
              for (final sdCard in sdCards) ...[
                const SizedBox(height: 12),
                _removableStorageCard(c, sdCard),
              ],
              const SizedBox(height: 30),
              Text(
                'Smart suggestions',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Review items before freeing space',
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _suggestionCard(
                c,
                title: 'Screenshots',
                subtitle: '${_screenshots.length} images to review',
                size: _screenshots.fold(0, (sum, item) => sum + item.fileSize),
                icon: CupertinoIcons.photo_fill,
                accent: c.accentTeal,
                items: _screenshots,
              ),
              const SizedBox(height: 10),
              _suggestionCard(
                c,
                title: 'Screen recordings',
                subtitle: '${_screenRecordings.length} videos to review',
                size: _screenRecordings.fold(
                  0,
                  (sum, item) => sum + item.fileSize,
                ),
                icon: CupertinoIcons.videocam_fill,
                accent: c.accentRose,
                items: _screenRecordings,
              ),
              const SizedBox(height: 10),
              _suggestionCard(
                c,
                title: 'Duplicate photos',
                subtitle: '${_duplicates.length} items',
                size: _duplicates.fold(0, (sum, item) => sum + item.fileSize),
                icon: CupertinoIcons.square_on_square,
                accent: c.accentGreen,
                items: _duplicates,
              ),
              const SizedBox(height: 10),
              _suggestionCard(
                c,
                title: 'Large videos',
                subtitle: '${_largeVideos.length} videos over 100 MB',
                size: _largeVideos.fold(0, (sum, item) => sum + item.fileSize),
                icon: CupertinoIcons.photo,
                accent: c.accentAmber,
                items: _largeVideos,
              ),
              const SizedBox(height: 10),
              _suggestionCard(
                c,
                title: 'Similar & blurry',
                subtitle: '${_similarOrBlurry.length} photos to review',
                size: _similarOrBlurry.fold(
                  0,
                  (sum, item) => sum + item.fileSize,
                ),
                icon: CupertinoIcons.rectangle_on_rectangle,
                accent: c.accentViolet,
                items: _similarOrBlurry,
              ),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle _eyebrow(AppThemeColors c) => TextStyle(
    color: c.textSecondary,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
  );

  Widget _storageCard(
    AppThemeColors c,
    int used,
    int? total,
    double progress,
    int reclaimableBytes,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: c.surface.withOpacity(c.isDark ? 0.92 : 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: c.primary.withOpacity(0.55), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: c.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 122,
            height: 122,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: reclaimableBytes == 0 ? 0.02 : progress,
                    strokeWidth: 13,
                    strokeCap: StrokeCap.round,
                    backgroundColor: c.surfaceElevated,
                    valueColor: AlwaysStoppedAnimation(c.primary),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _size(reclaimableBytes),
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    Text(
                      'can be saved',
                      style: TextStyle(color: c.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  total == null ? 'Gallery storage' : 'Phone storage',
                  style: TextStyle(color: c.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  total == null
                      ? _size(used)
                      : '${_size(used)} of ${_size(total)}',
                  maxLines: 1,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    color: c.primary,
                    backgroundColor: c.surfaceElevated,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: c.primary,
                    disabledColor: c.primary.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(22),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onPressed: _checking ? null : _checkSpace,
                    child: _checking
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CupertinoActivityIndicator(color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Checking...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Check My Space',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _removableStorageCard(AppThemeColors c, _StorageVolume volume) {
    final progress = volume.totalBytes == 0
        ? 0.0
        : (volume.usedBytes / volume.totalBytes).clamp(0.0, 1.0);
    final savings = _reclaimableForVolume(volume);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface.withOpacity(c.isDark ? 0.92 : 0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.accentGreen.withOpacity(0.45), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: c.accentGreen.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              CupertinoIcons.device_phone_portrait,
              color: c.accentGreen,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        volume.name,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${_size(volume.usedBytes)} of ${_size(volume.totalBytes)}',
                      style: TextStyle(color: c.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    color: c.accentGreen,
                    backgroundColor: c.surfaceElevated,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  savings > 0
                      ? '${_size(savings)} can be saved from this card'
                      : '${_size(volume.freeBytes)} available',
                  style: TextStyle(color: c.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _reclaimableForVolume(_StorageVolume volume) {
    if (_volumes.length == 1 && !volume.removable) return _reclaimableBytes;
    if (volume.rootPath.isEmpty) return 0;
    final unique = <String, MediaItem>{};
    for (final item in [
      ..._duplicates,
      ..._largeVideos,
      ..._similarOrBlurry,
      ..._screenshots,
      ..._screenRecordings,
    ]) {
      if ((item.localFilePath ?? '').startsWith(volume.rootPath)) {
        unique[item.localId] = item;
      }
    }
    return unique.values.fold(0, (sum, item) => sum + item.fileSize);
  }

  Widget _suggestionCard(
    AppThemeColors c, {
    required String title,
    required String subtitle,
    required int size,
    required IconData icon,
    required Color accent,
    required List<MediaItem> items,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: items.isEmpty ? null : () => _showReviewSheet(title, items),
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: c.surface.withOpacity(c.isDark ? 0.94 : 0.98),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.glassBorder, width: 0.7),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.14),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: accent, size: 24),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    items.isEmpty ? 'No items found' : subtitle,
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              items.isEmpty ? '—' : _size(size),
              style: TextStyle(
                color: accent,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Icon(CupertinoIcons.chevron_right, color: c.textTertiary, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showReviewSheet(String title, List<MediaItem> source) async {
    final items = List<MediaItem>.from(source);
    final selectedIds = <String>{};
    var deleting = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final c = AppTheme.colors(context);
          return Container(
            height: MediaQuery.sizeOf(context).height * 0.72,
            decoration: BoxDecoration(
              color: c.bgSecondary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 38,
                    height: 5,
                    decoration: BoxDecoration(
                      color: c.textTertiary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                selectedIds.isEmpty
                                    ? '${items.length} items'
                                    : '${selectedIds.length} selected',
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (items.isNotEmpty)
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            onPressed: deleting
                                ? null
                                : () {
                                    setSheetState(() {
                                      if (selectedIds.length == items.length) {
                                        selectedIds.clear();
                                      } else {
                                        selectedIds
                                          ..clear()
                                          ..addAll(
                                            items.map((item) => item.localId),
                                          );
                                      }
                                    });
                                  },
                            child: Text(
                              selectedIds.length == items.length
                                  ? 'Deselect All'
                                  : 'Select All',
                              style: TextStyle(
                                color: c.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'Done',
                            style: TextStyle(
                              color: c.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: EdgeInsets.fromLTRB(
                        14,
                        0,
                        14,
                        selectedIds.isEmpty ? 18 : 92,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 5,
                            mainAxisSpacing: 5,
                            childAspectRatio: 0.82,
                          ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final selected = selectedIds.contains(item.localId);
                        return GestureDetector(
                          onTap: deleting
                              ? null
                              : () {
                                  setSheetState(() {
                                    if (selected) {
                                      selectedIds.remove(item.localId);
                                    } else {
                                      selectedIds.add(item.localId);
                                    }
                                  });
                                },
                          onLongPress: deleting
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    PageRouteBuilder<void>(
                                      opaque: false,
                                      barrierColor: Colors.black,
                                      transitionDuration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      reverseTransitionDuration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      pageBuilder: (_, _, _) =>
                                          MediaPreviewScreen(
                                            items: [item],
                                            initialIndex: 0,
                                          ),
                                      transitionsBuilder:
                                          (_, animation, _, child) =>
                                              FadeTransition(
                                                opacity: animation,
                                                child: child,
                                              ),
                                    ),
                                  );
                                },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: selected ? c.primary : c.glassBorder,
                                width: selected ? 2.5 : 0.7,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedThumbnailImage(
                                  localId: item.localId,
                                  filePath: item.localFilePath,
                                  isVideo: item.isVideo,
                                  size: 260,
                                  placeholder: Container(
                                    color: c.surfaceElevated,
                                    child: Icon(
                                      item.isVideo
                                          ? CupertinoIcons.videocam_fill
                                          : CupertinoIcons.photo_fill,
                                      color: c.textTertiary,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(
                                      7,
                                      18,
                                      7,
                                      6,
                                    ),
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Color(0xCC000000),
                                        ],
                                      ),
                                    ),
                                    child: Text(
                                      item.fileName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 7,
                                  right: 7,
                                  child: Container(
                                    width: 25,
                                    height: 25,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: selected
                                          ? c.primary
                                          : Colors.black.withOpacity(0.48),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: selected
                                        ? const Icon(
                                            CupertinoIcons.checkmark,
                                            color: Colors.white,
                                            size: 15,
                                          )
                                        : null,
                                  ),
                                ),
                                if (item.isVideo)
                                  const Center(
                                    child: Icon(
                                      CupertinoIcons.play_circle_fill,
                                      color: Colors.white,
                                      size: 31,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (selectedIds.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      decoration: BoxDecoration(
                        color: c.surface,
                        border: Border(
                          top: BorderSide(color: c.glassBorder, width: 0.7),
                        ),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          color: c.accentRose,
                          disabledColor: c.accentRose.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(20),
                          onPressed: deleting
                              ? null
                              : () async {
                                  final selectedItems = items
                                      .where(
                                        (item) =>
                                            selectedIds.contains(item.localId),
                                      )
                                      .toList();
                                  final confirmed =
                                      await showCupertinoDialog<bool>(
                                        context: context,
                                        builder: (dialogContext) =>
                                            CupertinoAlertDialog(
                                              title: Text(
                                                'Delete ${selectedItems.length} items?',
                                              ),
                                              content: const Text(
                                                'The selected files will be permanently removed from the device.',
                                              ),
                                              actions: [
                                                CupertinoDialogAction(
                                                  child: const Text('Cancel'),
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        dialogContext,
                                                        false,
                                                      ),
                                                ),
                                                CupertinoDialogAction(
                                                  isDestructiveAction: true,
                                                  child: const Text('Delete'),
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        dialogContext,
                                                        true,
                                                      ),
                                                ),
                                              ],
                                            ),
                                      ) ??
                                      false;
                                  if (!confirmed || !context.mounted) return;
                                  setSheetState(() => deleting = true);
                                  final deletedIds = <String>{};
                                  for (final item in selectedItems) {
                                    if (await widget.onDelete(item)) {
                                      deletedIds.add(item.localId);
                                    }
                                  }
                                  if (!mounted || !context.mounted) return;
                                  setSheetState(() {
                                    items.removeWhere(
                                      (item) =>
                                          deletedIds.contains(item.localId),
                                    );
                                    selectedIds.removeAll(deletedIds);
                                    deleting = false;
                                  });
                                  setState(() {});
                                },
                          child: deleting
                              ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CupertinoActivityIndicator(
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Deleting...',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                )
                              : Text(
                                  'Delete ${selectedIds.length} selected',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StorageVolume {
  const _StorageVolume({
    required this.name,
    required this.rootPath,
    required this.totalBytes,
    required this.freeBytes,
    required this.removable,
  });

  factory _StorageVolume.fromMap(Map<dynamic, dynamic> map) {
    return _StorageVolume(
      name: map['name'] as String? ?? 'Storage',
      rootPath: map['rootPath'] as String? ?? '',
      totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
      freeBytes: (map['freeBytes'] as num?)?.toInt() ?? 0,
      removable: map['removable'] as bool? ?? false,
    );
  }

  final String name;
  final String rootPath;
  final int totalBytes;
  final int freeBytes;
  final bool removable;

  int get usedBytes => (totalBytes - freeBytes).clamp(0, totalBytes);
}
