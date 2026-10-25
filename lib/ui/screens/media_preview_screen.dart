import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../models/media_item.dart';
import '../../providers/backup_provider.dart';
import '../../services/device_settings_helper.dart';
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

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  late PageController _pageController;
  late List<MediaItem> _items;
  late int _currentIndex;
  bool _showControls = true;

  // Active video controller for video playback
  VideoPlayerController? _videoController;
  int? _activeVideoIndex;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _items = List<MediaItem>.from(widget.items);
    _currentIndex = widget.initialIndex.clamp(0, _items.isEmpty ? 0 : _items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);

    if (_items.isNotEmpty) {
      _checkAndInitVideo(_currentIndex);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _pageController.dispose();
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
    _checkAndInitVideo(index);
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
            backgroundColor: Colors.redAccent,
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
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete from device?', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Text(
          'Are you sure you want to delete "${item.fileName}" from your device storage?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
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
            backgroundColor: const Color(0xFF2C2C2C),
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
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
            const SizedBox(height: 18),
            const Text(
              'Details',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(Icons.description_outlined, 'Name', item.fileName),
            _buildDetailRow(Icons.folder_outlined, 'Album', item.displayFolderName),
            _buildDetailRow(Icons.calendar_today_outlined, 'Date', df.format(item.createdAt)),
            _buildDetailRow(Icons.data_usage_outlined, 'File Size', item.formattedSize),
            if (item.width != null && item.height != null && item.width! > 0 && item.height! > 0)
              _buildDetailRow(Icons.aspect_ratio_outlined, 'Resolution', '${item.width} × ${item.height}'),
            if (item.mediaType == AppMediaType.video && item.durationSeconds != null)
              _buildDetailRow(Icons.timer_outlined, 'Duration', item.formattedDuration),
            if (item.localFilePath != null)
              _buildDetailRow(Icons.sd_storage_outlined, 'Path', item.localFilePath!),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.white54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
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
        body: Center(child: Text('No media items', style: TextStyle(color: Colors.white54))),
      );
    }

    final currentItem = _items[_currentIndex];
    final isVideo = currentItem.mediaType == AppMediaType.video;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Swipeable Full-Screen PageView
          GestureDetector(
            onTap: _toggleControls,
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

          // 2. Top Header Bar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: _showControls ? 0 : -100,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 4,
                left: 8,
                right: 16,
                bottom: 12,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
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
                          style: const TextStyle(
                            color: Colors.white70,
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

          // 3. Bottom Action Bar (Share, Info, Delete) + Video Scrubber
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            bottom: _showControls ? 0 : -120,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 12,
                left: 24,
                right: 24,
                top: 12,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
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
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Colors.white,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              trackHeight: 3,
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
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],

                  // Action Buttons: Share, Info, Delete
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: Icons.share_outlined,
                        label: 'Share',
                        onTap: _shareCurrentItem,
                      ),
                      _buildActionButton(
                        icon: Icons.info_outline,
                        label: 'Details',
                        onTap: _showItemDetailsBottomSheet,
                      ),
                      _buildActionButton(
                        icon: Icons.delete_outline,
                        label: 'Delete',
                        color: Colors.redAccent,
                        onTap: _confirmAndDeleteCurrentItem,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePage(MediaItem item) {
    return FutureBuilder<Uint8List?>(
      future: MediaScannerService.instance.getThumbnail(item.localId, size: 1080),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.data != null && snapshot.data!.isNotEmpty) {
            return InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Center(
                child: Image.memory(
                  snapshot.data!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => _buildMissingFileError(),
                ),
              ),
            );
          } else {
            return _buildMissingFileError();
          }
        }
        return const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        );
      },
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
            // Play/Pause Center Button
            if (!_videoController!.value.isPlaying)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(12),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
              ),
          ],
        ),
      );
    }

    // Fallback thumbnail while video initializes
    return FutureBuilder<Uint8List?>(
      future: MediaScannerService.instance.getThumbnail(item.localId, size: 800),
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
                    errorBuilder: (context, error, stackTrace) => _buildMissingFileError(),
                  ),
                  const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ],
              ),
            );
          } else {
            return _buildMissingFileError();
          }
        }
        return const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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
            const Icon(Icons.broken_image_outlined, color: Colors.white38, size: 64),
            const SizedBox(height: 16),
            const Text(
              'File no longer exists on device',
              style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
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
                backgroundColor: Colors.white12,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
