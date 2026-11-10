import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../services/device_settings_helper.dart';
import '../../services/favorites_service.dart';
import '../../services/memories_service.dart';
import '../../services/media_scanner_service.dart';
import 'photo_editor_screen.dart';
import 'video_editor_screen.dart';

class MemoriesStoryScreen extends StatefulWidget {
  final List<MemoryGroup> memories;
  final int initialGroupIndex;

  const MemoriesStoryScreen({
    super.key,
    required this.memories,
    this.initialGroupIndex = 0,
  });

  @override
  State<MemoriesStoryScreen> createState() => _MemoriesStoryScreenState();
}

class _MemoriesStoryScreenState extends State<MemoriesStoryScreen>
    with SingleTickerProviderStateMixin {
  late int _currentGroupIndex;
  int _currentItemIndex = 0;

  // Story progress timer
  late AnimationController _progressController;
  bool _isPaused = false;

  // Active video controller if current moment is a video
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  // Swipe-down dismiss drag offset
  double _dragOffsetY = 0.0;

  MemoryGroup get _currentGroup => widget.memories[_currentGroupIndex];
  MediaItem get _currentItem => _currentGroup.items[_currentItemIndex];

  @override
  void initState() {
    super.initState();
    _currentGroupIndex = widget.initialGroupIndex.clamp(0, widget.memories.length - 1);

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _advanceToNext();
        }
      });

    _loadCurrentItem();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentItem() async {
    _progressController.stop();
    _progressController.reset();

    await _videoController?.dispose();
    _videoController = null;
    _isVideoInitialized = false;

    final item = _currentItem;

    if (item.mediaType == AppMediaType.video) {
      try {
        final file = await MediaScannerService.instance.getMediaFile(item.localId);
        if (file != null && await file.exists()) {
          final controller = VideoPlayerController.file(file);
          await controller.initialize();
          if (mounted) {
            setState(() {
              _videoController = controller;
              _isVideoInitialized = true;
            });
            final duration = controller.value.duration;
            _progressController.duration = duration > Duration.zero
                ? duration
                : const Duration(seconds: 5);
            controller.play();
            _progressController.forward();
            return;
          }
        }
      } catch (_) {}
    }

    // Photo defaults
    _progressController.duration = const Duration(milliseconds: 4500);
    if (!_isPaused && mounted) {
      _progressController.forward();
      setState(() {});
    }
  }

  void _advanceToNext() {
    if (_currentItemIndex < _currentGroup.items.length - 1) {
      setState(() {
        _currentItemIndex++;
      });
      _loadCurrentItem();
    } else if (_currentGroupIndex < widget.memories.length - 1) {
      setState(() {
        _currentGroupIndex++;
        _currentItemIndex = 0;
      });
      _loadCurrentItem();
    } else {
      // Completed all memories
      Navigator.of(context).pop();
    }
  }

  void _goToPrevious() {
    if (_currentItemIndex > 0) {
      setState(() {
        _currentItemIndex--;
      });
      _loadCurrentItem();
    } else if (_currentGroupIndex > 0) {
      setState(() {
        _currentGroupIndex--;
        _currentItemIndex = widget.memories[_currentGroupIndex].items.length - 1;
      });
      _loadCurrentItem();
    } else {
      _progressController.reset();
      _progressController.forward();
    }
  }

  void _pauseStory() {
    setState(() => _isPaused = true);
    _progressController.stop();
    _videoController?.pause();
  }

  void _resumeStory() {
    setState(() => _isPaused = false);
    _progressController.forward();
    _videoController?.play();
  }

  Future<void> _shareCurrentItem() async {
    _pauseStory();
    final item = _currentItem;
    File? file;
    if (item.localFilePath != null) {
      final f = File(item.localFilePath!);
      if (await f.exists()) file = f;
    }
    file ??= await MediaScannerService.instance.getMediaFile(item.localId);
    if (file != null && await file.exists()) {
      await DeviceSettingsHelper.shareMediaFile(file.path, item.mimeType);
    }
    _resumeStory();
  }

  Future<void> _editCurrentItem() async {
    _pauseStory();
    final item = _currentItem;

    if (item.mediaType == AppMediaType.video) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VideoEditorScreen(item: item)),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PhotoEditorScreen(item: item)),
      );
    }

    _resumeStory();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final favService = FavoritesService.instance;
    final isFav = favService.isFavorite(_currentItem.localId);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF000000),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF000000),
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Color(0xFF000000),
        systemNavigationBarContrastEnforced: false,
        systemStatusBarContrastEnforced: false,
      ),
      child: Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta != null && details.primaryDelta! > 0) {
            setState(() {
              _dragOffsetY += details.primaryDelta!;
            });
          }
        },
        onVerticalDragEnd: (details) {
          if (_dragOffsetY > 120) {
            Navigator.of(context).pop();
          } else {
            setState(() => _dragOffsetY = 0.0);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          transform: Matrix4.translationValues(0.0, _dragOffsetY, 0.0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Main Media Display
              _buildMediaViewer(),

              // Left & Right Tap Touch Handlers
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _goToPrevious,
                      onLongPressStart: (_) => _pauseStory(),
                      onLongPressEnd: (_) => _resumeStory(),
                      child: Container(),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _advanceToNext,
                      onLongPressStart: (_) => _pauseStory(),
                      onLongPressEnd: (_) => _resumeStory(),
                      child: Container(),
                    ),
                  ),
                ],
              ),

              // Top Gradient Overlay with Segmented Progress Bar & Title
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 14,
                    right: 14,
                    bottom: 24,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Segmented Story Bars
                      _buildSegmentedBars(),
                      const SizedBox(height: 12),

                      // Title & Close Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentGroup.title.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('MMMM d, yyyy').format(_currentItem.createdAt),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minSize: 0,
                            onPressed: () => Navigator.of(context).pop(),
                            child: Icon(
                              CupertinoIcons.xmark_circle_fill,
                              color: Colors.white.withOpacity(0.7),
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Glass Floating Toolbar
              Positioned(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).padding.bottom > 0
                    ? MediaQuery.of(context).padding.bottom + 8
                    : 20,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.all(8),
                            minSize: 0,
                            onPressed: _shareCurrentItem,
                            child: const Icon(CupertinoIcons.share, color: Colors.white, size: 22),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.all(8),
                            minSize: 0,
                            onPressed: () async {
                              await favService.toggleFavorite(_currentItem.localId);
                              setState(() {});
                            },
                            child: Icon(
                              isFav ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                              color: isFav ? c.accentRose : Colors.white,
                              size: 22,
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.all(8),
                            minSize: 0,
                            onPressed: _editCurrentItem,
                            child: const Icon(CupertinoIcons.slider_horizontal_3, color: Colors.white, size: 22),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildSegmentedBars() {
    final count = _currentGroup.items.length;
    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, _) {
        return Row(
          children: List.generate(count, (index) {
            double progress = 0.0;
            if (index < _currentItemIndex) {
              progress = 1.0;
            } else if (index == _currentItemIndex) {
              progress = _progressController.value;
            }

            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 2.5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildMediaViewer() {
    final item = _currentItem;

    if (item.mediaType == AppMediaType.video && _isVideoInitialized && _videoController != null) {
      return Center(
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
      );
    }

    if (item.localFilePath != null) {
      final f = File(item.localFilePath!);
      return Image.file(
        f,
        fit: BoxFit.contain,
        errorBuilder: (_, error, stack) => _buildFallbackThumbnail(item),
      );
    }

    return _buildFallbackThumbnail(item);
  }

  Widget _buildFallbackThumbnail(MediaItem item) {
    return FutureBuilder<File?>(
      future: MediaScannerService.instance.getMediaFile(item.localId),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.file(snapshot.data!, fit: BoxFit.contain);
        }
        return const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        );
      },
    );
  }
}
