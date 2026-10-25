import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../providers/backup_provider.dart';
import '../../services/device_settings_helper.dart';
import '../../services/favorites_service.dart';
import '../../services/media_scanner_service.dart';

class MediaPreviewScreen extends StatefulWidget {
  final List<MediaItem> items;
  final int initialIndex;

  const MediaPreviewScreen({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  /// Factory for previewing a single item
  factory MediaPreviewScreen.single({Key? key, required MediaItem item}) {
    return MediaPreviewScreen(
      key: key,
      items: [item],
      initialIndex: 0,
    );
  }

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late List<MediaItem> _items;
  late int _currentIndex;
  bool _showControls = true;

  // Active video controller for video playback
  VideoPlayerController? _videoController;
  int? _activeVideoIndex;
  bool _isVideoInitialized = false;

  // Zoom controller for interactive viewer
  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _zoomAnimController;
  Animation<Matrix4>? _zoomAnimation;

  @override
  void initState() {
    super.initState();
    _items = List<MediaItem>.from(widget.items);
    _currentIndex =
        widget.initialIndex.clamp(0, _items.isEmpty ? 0 : _items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);

    _zoomAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _transformationController.value = _zoomAnimation!.value;
        }
      });

    if (_items.isNotEmpty) {
      _checkAndInitVideo(_currentIndex);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _pageController.dispose();
    _zoomAnimController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _transformationController.value = Matrix4.identity();
    _checkAndInitVideo(index);
  }

  void _handleDoubleTapZoom(TapDownDetails details) {
    final currentMatrix = _transformationController.value;
    final isZoomed = !currentMatrix.isIdentity();

    Matrix4 targetMatrix;
    if (isZoomed) {
      targetMatrix = Matrix4.identity();
    } else {
      final pos = details.localPosition;
      targetMatrix = Matrix4.identity()
        ..translate(-pos.dx * 1.5, -pos.dy * 1.5)
        ..scale(2.5);
    }

    _zoomAnimation = Matrix4Tween(
      begin: currentMatrix,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _zoomAnimController,
      curve: Curves.easeOutCubic,
    ));

    _zoomAnimController.forward(from: 0);
  }

  Future<void> _checkAndInitVideo(int index) async {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];

    // Dispose previous video controller
    await _videoController?.dispose();
    _videoController = null;
    _isVideoInitialized = false;
    _activeVideoIndex = null;

    if (item.mediaType == AppMediaType.video) {
      File? file;
      if (item.localFilePath != null) {
        final f = File(item.localFilePath!);
        if (await f.exists()) file = f;
      }
      file ??= await MediaScannerService.instance.getMediaFile(item.localId);

      if (file != null && mounted) {
        try {
          final controller = VideoPlayerController.file(file);
          await controller.initialize();
          controller.setLooping(true);
          controller.addListener(() {
            if (mounted) setState(() {});
          });

          if (mounted) {
            setState(() {
              _videoController = controller;
              _activeVideoIndex = index;
              _isVideoInitialized = true;
            });
          }
        } catch (e) {
          debugPrint('Error loading video: $e');
        }
      }
    }
  }

  Future<void> _shareCurrentItem() async {
    if (_items.isEmpty) return;
    final item = _items[_currentIndex];

    File? file;
    if (item.localFilePath != null) {
      final f = File(item.localFilePath!);
      if (await f.exists()) file = f;
    }
    file ??= await MediaScannerService.instance.getMediaFile(item.localId);

    if (file != null && await file.exists()) {
      await DeviceSettingsHelper.shareMediaFile(file.path, item.mimeType);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File not found on device storage'),
            backgroundColor: AppTheme.roseDanger,
          ),
        );
      }
    }
  }

  Future<void> _confirmAndDeleteCurrentItem() async {
    if (_items.isEmpty) return;
    final item = _items[_currentIndex];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D31),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: Colors.white.withOpacity(0.12),
            width: 1.2,
          ),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppTheme.roseDanger, size: 24),
            SizedBox(width: 10),
            Text('Delete File?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${item.fileName}" from device storage?',
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
              elevation: 4,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<BackupProvider>();
      final deleted = await provider.deleteMediaItem(item);

      if (mounted) {
        setState(() {
          _items.removeAt(_currentIndex);
          if (_items.isEmpty) {
            Navigator.of(context).pop();
            return;
          }
          if (_currentIndex >= _items.length) {
            _currentIndex = _items.length - 1;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(deleted ? 'Item deleted from device' : 'Removed from gallery'),
            backgroundColor: const Color(0xFF1C2740),
            duration: const Duration(seconds: 2),
          ),
        );

        _checkAndInitVideo(_currentIndex);
      }
    }
  }

  void _showItemDetailsBottomSheet() {
    if (_items.isEmpty) return;
    final item = _items[_currentIndex];
    final df = DateFormat('d MMMM yyyy, h:mm a');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0C1322),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: Colors.white.withOpacity(0.12),
            width: 1.2,
          ),
          boxShadow: AppTheme.depthShadow(
            depth: 20,
            glowColor: AppTheme.primaryAccent,
            glowOpacity: 0.12,
          ),
        ),
        padding: EdgeInsets.only(
          top: 14,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryAccent, AppTheme.primaryBlue],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryAccent.withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.info_outline_rounded, color: Colors.black, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Media Details & EXIF',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 3D Grid of Stat Cards
            Row(
              children: [
                Expanded(
                  child: _buildDetailCard(
                    Icons.aspect_ratio_rounded,
                    'Resolution',
                    item.formattedDimensions.isNotEmpty
                        ? item.formattedDimensions
                        : 'Standard',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildDetailCard(
                    Icons.data_usage_rounded,
                    'File Size',
                    item.formattedSize,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildDetailCard(
                    Icons.folder_outlined,
                    'Album',
                    item.displayFolderName,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildDetailCard(
                    Icons.extension_outlined,
                    'Format',
                    item.mimeType.split('/').last.toUpperCase(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _buildDetailRow(Icons.description_outlined, 'File Name', item.fileName),
            _buildDetailRow(Icons.calendar_today_outlined, 'Date Taken', df.format(item.createdAt)),
            if (item.localFilePath != null)
              _buildDetailRow(Icons.sd_storage_outlined, 'Storage Path', item.localFilePath!),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.white38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('No media items', style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    final currentItem = _items[_currentIndex];
    final isVideo = currentItem.mediaType == AppMediaType.video;
    final isFavorite = FavoritesService.instance.isFavorite(currentItem.localId);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Swipeable Full-Screen PageView with Double-Tap Zoom
          GestureDetector(
            onTap: _toggleControls,
            onDoubleTapDown: _handleDoubleTapZoom,
            onDoubleTap: () {},
            behavior: HitTestBehavior.opaque,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _items.length,
              onPageChanged: _onPageChanged,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final item = _items[index];
                if (item.mediaType == AppMediaType.video) {
                  return _buildVideoPage(index, item);
                } else {
                  return _buildImagePage(item);
                }
              },
            ),
          ),

          // 2. Top Frosted Header Bar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            top: _showControls ? 0 : -120,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 6,
                left: 10,
                right: 16,
                bottom: 14,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.85),
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentItem.fileName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${currentItem.displayFolderName} • ${_currentIndex + 1} of ${_items.length}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Bottom Floating 3D Frosted Capsule Action Bar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            bottom: _showControls ? 0 : -140,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                left: 20,
                right: 20,
                top: 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.85),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Video Scrubber (if video is currently active)
                  if (isVideo && _isVideoInitialized && _videoController != null) ...[
                    Row(
                      children: [
                        Text(
                          _formatDuration(_videoController!.value.position),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppTheme.primaryAccent,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: AppTheme.primaryAccent,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              trackHeight: 3.5,
                            ),
                            child: Slider(
                              value: _videoController!.value.position.inMilliseconds
                                  .toDouble()
                                  .clamp(0.0, _videoController!.value.duration.inMilliseconds.toDouble()),
                              min: 0.0,
                              max: _videoController!.value.duration.inMilliseconds.toDouble(),
                              onChanged: (val) {
                                _videoController!.seekTo(Duration(milliseconds: val.toInt()));
                              },
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(_videoController!.value.duration),
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],

                  // 3D Floating Action Capsule with Glass Blur
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.14),
                            width: 1.2,
                          ),
                          boxShadow: AppTheme.depthShadow(
                            depth: 12,
                            glowColor: AppTheme.primaryAccent,
                            glowOpacity: 0.15,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildCapsuleAction(
                              icon: Icons.share_rounded,
                              label: 'Share',
                              onTap: _shareCurrentItem,
                            ),
                            _buildCapsuleAction(
                              icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              label: 'Favorite',
                              color: isFavorite ? AppTheme.roseDanger : Colors.white,
                              iconGlow: isFavorite,
                              onTap: () async {
                                await FavoritesService.instance.toggleFavorite(currentItem.localId);
                                setState(() {});
                              },
                            ),
                            _buildCapsuleAction(
                              icon: Icons.info_outline_rounded,
                              label: 'Details',
                              onTap: _showItemDetailsBottomSheet,
                            ),
                            _buildCapsuleAction(
                              icon: Icons.delete_outline_rounded,
                              label: 'Delete',
                              color: AppTheme.roseDanger,
                              onTap: _confirmAndDeleteCurrentItem,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapsuleAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
    bool iconGlow = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: iconGlow
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    )
                  : null,
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.85),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePage(MediaItem item) {
    return _FullImagePreviewPage(
      key: ValueKey('preview_full_${item.localId}'),
      item: item,
      transformationController: _transformationController,
      errorBuilder: _buildMissingFileError,
    );
  }

  Widget _buildVideoPage(int index, MediaItem item) {
    if (_activeVideoIndex == index && _isVideoInitialized && _videoController != null) {
      return Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio > 0
                  ? _videoController!.value.aspectRatio
                  : 16 / 9,
              child: VideoPlayer(_videoController!),
            ),
            // 3D Frosted Play/Pause Center Button
            if (!_videoController!.value.isPlaying)
              GestureDetector(
                onTap: () {
                  _videoController!.play();
                  setState(() {});
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1.5,
                    ),
                    boxShadow: AppTheme.depthShadow(
                      depth: 12,
                      glowColor: AppTheme.primaryAccent,
                      glowOpacity: 0.3,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: AppTheme.primaryAccent,
                    size: 48,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // High quality video thumbnail fallback
    final cachedBytes =
        MediaScannerService.instance.getCachedThumbnail(item.localId);
    if (cachedBytes != null && cachedBytes.isNotEmpty) {
      return Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.memory(
              cachedBytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) =>
                  _buildMissingFileError(),
            ),
            const CircularProgressIndicator(
              color: AppTheme.primaryAccent,
              strokeWidth: 2.5,
            ),
          ],
        ),
      );
    }

    return FutureBuilder<Uint8List?>(
      future: MediaScannerService.instance.getThumbnail(item.localId, size: 800, quality: 95),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.data != null && snapshot.data!.isNotEmpty) {
            return Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.memory(
                    snapshot.data!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildMissingFileError(),
                  ),
                  const CircularProgressIndicator(
                    color: AppTheme.primaryAccent,
                    strokeWidth: 2.5,
                  ),
                ],
              ),
            );
          } else {
            return _buildMissingFileError();
          }
        }
        return const Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryAccent,
            strokeWidth: 2.5,
          ),
        );
      },
    );
  }

  Widget _buildMissingFileError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined,
                color: Colors.white38, size: 64),
            const SizedBox(height: 16),
            const Text(
              'File no longer exists on device',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'This media item was deleted from device storage by another file manager or gallery.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back to Gallery'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.darkCardBorder,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dedicated full-resolution image viewer: renders the original uncompressed file
/// from storage for 100% true camera quality, while displaying the cached thumbnail
/// instantaneously on frame 0 to eliminate blank flickers during hero transitions.
class _FullImagePreviewPage extends StatefulWidget {
  final MediaItem item;
  final TransformationController transformationController;
  final Widget Function() errorBuilder;

  const _FullImagePreviewPage({
    super.key,
    required this.item,
    required this.transformationController,
    required this.errorBuilder,
  });

  @override
  State<_FullImagePreviewPage> createState() => _FullImagePreviewPageState();
}

class _FullImagePreviewPageState extends State<_FullImagePreviewPage> {
  File? _resolvedFile;
  Uint8List? _resolvedBytes;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _resolveFullResolutionMedia();
  }

  @override
  void didUpdateWidget(_FullImagePreviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.localId != widget.item.localId) {
      _resolvedFile = null;
      _resolvedBytes = null;
      _hasError = false;
      _resolveFullResolutionMedia();
    }
  }

  Future<void> _resolveFullResolutionMedia() async {
    // 1. Check direct local file path if available
    if (widget.item.localFilePath != null && widget.item.localFilePath!.isNotEmpty) {
      final f = File(widget.item.localFilePath!);
      if (await f.exists()) {
        if (mounted) {
          setState(() {
            _resolvedFile = f;
          });
          return;
        }
      }
    }

    // 2. Resolve origin / full file via MediaScannerService
    try {
      final file = await MediaScannerService.instance.getMediaFile(widget.item.localId);
      if (file != null && await file.exists()) {
        if (mounted) {
          setState(() {
            _resolvedFile = file;
          });
          return;
        }
      }
    } catch (_) {}

    // 3. Fallback: retrieve origin uncompressed bytes from AssetEntity
    try {
      final asset = await AssetEntity.fromId(widget.item.localId);
      if (asset != null) {
        final originBytes = await asset.originBytes;
        if (originBytes != null && originBytes.isNotEmpty) {
          if (mounted) {
            setState(() {
              _resolvedBytes = originBytes;
            });
            return;
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cachedThumbnail =
        MediaScannerService.instance.getCachedThumbnail(widget.item.localId);

    // 1. Full original file: 100% raw uncompressed camera/download quality
    if (_resolvedFile != null) {
      return InteractiveViewer(
        transformationController: widget.transformationController,
        minScale: 1.0,
        maxScale: 5.0,
        child: Center(
          child: Hero(
            tag: 'media_tile_${widget.item.localId}',
            child: Image.file(
              _resolvedFile!,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => widget.errorBuilder(),
            ),
          ),
        ),
      );
    }

    // 2. Full origin bytes fallback
    if (_resolvedBytes != null && _resolvedBytes!.isNotEmpty) {
      return InteractiveViewer(
        transformationController: widget.transformationController,
        minScale: 1.0,
        maxScale: 5.0,
        child: Center(
          child: Hero(
            tag: 'media_tile_${widget.item.localId}',
            child: Image.memory(
              _resolvedBytes!,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => widget.errorBuilder(),
            ),
          ),
        ),
      );
    }

    // 3. Error state if file no longer exists
    if (_hasError) {
      return widget.errorBuilder();
    }

    // 4. Instant frame-0 placeholder: show cached thumbnail while full file decodes
    if (cachedThumbnail != null && cachedThumbnail.isNotEmpty) {
      return InteractiveViewer(
        transformationController: widget.transformationController,
        minScale: 1.0,
        maxScale: 5.0,
        child: Center(
          child: Hero(
            tag: 'media_tile_${widget.item.localId}',
            child: Image.memory(
              cachedThumbnail,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        ),
      );
    }

    return const Center(
      child: CircularProgressIndicator(
        color: AppTheme.primaryAccent,
        strokeWidth: 2.5,
      ),
    );
  }
}
