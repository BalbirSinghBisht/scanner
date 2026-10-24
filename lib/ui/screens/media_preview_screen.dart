import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../models/media_item.dart';
import '../../services/media_scanner_service.dart';

class MediaPreviewScreen extends StatefulWidget {
  final MediaItem item;

  const MediaPreviewScreen({
    super.key,
    required this.item,
  });

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  bool _showControls = true;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  File? _resolvedFile;
  bool _isLoadingFile = true;

  @override
  void initState() {
    super.initState();
    _loadFileAndInitialize();
  }

  Future<void> _loadFileAndInitialize() async {
    // 1. Resolve local file
    File? file;
    if (widget.item.localFilePath != null) {
      final f = File(widget.item.localFilePath!);
      if (await f.exists()) {
        file = f;
      }
    }
    file ??= await MediaScannerService.instance.getMediaFile(widget.item.localId);

    if (!mounted) return;

    setState(() {
      _resolvedFile = file;
      _isLoadingFile = false;
    });

    // 2. If video, initialize video player
    if (widget.item.mediaType == AppMediaType.video && file != null) {
      try {
        _videoController = VideoPlayerController.file(file);
        await _videoController!.initialize();
        _videoController!.setLooping(true);
        _videoController!.addListener(() {
          if (mounted) setState(() {});
        });
        setState(() {
          _isVideoInitialized = true;
        });
        _videoController!.play();
      } catch (e) {
        debugPrint('Error initializing video player: $e');
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.item.mediaType == AppMediaType.video;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Center Media Content
          GestureDetector(
            onTap: _toggleControls,
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: isVideo ? _buildVideoViewer() : _buildImageViewer(),
            ),
          ),

          // Top Header Bar
          if (_showControls)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
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
                            widget.item.fileName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            widget.item.displayFolderName,
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

          // Video Controls at bottom
          if (isVideo && _showControls && _isVideoInitialized && _videoController != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 12,
                  left: 16,
                  right: 16,
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
                    // Scrubber slider
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
                                  .clamp(
                                    0.0,
                                    _videoController!.value.duration.inMilliseconds.toDouble(),
                                  ),
                              min: 0.0,
                              max: _videoController!.value.duration.inMilliseconds.toDouble() > 0
                                  ? _videoController!.value.duration.inMilliseconds.toDouble()
                                  : 1.0,
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
                    const SizedBox(height: 4),
                    // Play/Pause button
                    IconButton(
                      iconSize: 42,
                      icon: Icon(
                        _videoController!.value.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          if (_videoController!.value.isPlaying) {
                            _videoController!.pause();
                          } else {
                            _videoController!.play();
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageViewer() {
    if (_resolvedFile != null) {
      return InteractiveViewer(
        minScale: 0.8,
        maxScale: 4.0,
        child: Image.file(
          _resolvedFile!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildFallbackThumbnail(),
        ),
      );
    }

    if (_isLoadingFile) {
      return _buildFallbackThumbnail(showLoader: true);
    }

    return _buildFallbackThumbnail();
  }

  Widget _buildVideoViewer() {
    if (_isVideoInitialized && _videoController != null) {
      return Center(
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio > 0
              ? _videoController!.value.aspectRatio
              : 16 / 9,
          child: VideoPlayer(_videoController!),
        ),
      );
    }

    if (_isLoadingFile || !_isVideoInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _buildFallbackThumbnail(),
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ],
      );
    }

    return _buildFallbackThumbnail();
  }

  Widget _buildFallbackThumbnail({bool showLoader = false}) {
    return FutureBuilder<Uint8List?>(
      future: MediaScannerService.instance.getThumbnail(widget.item.localId, size: 800),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          return InteractiveViewer(
            minScale: 0.8,
            maxScale: 3.0,
            child: Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
            ),
          );
        }
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      },
    );
  }
}
