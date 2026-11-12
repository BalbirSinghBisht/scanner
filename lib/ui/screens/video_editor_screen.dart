import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../services/media_editor_service.dart';
import '../../services/media_scanner_service.dart';

class VideoEditorScreen extends StatefulWidget {
  final MediaItem item;

  const VideoEditorScreen({super.key, required this.item});

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  VideoPlayerController? _controller;
  File? _videoFile;
  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;

  // Trimming State (in Milliseconds)
  int _totalDurationMs = 0;
  int _startTrimMs = 0;
  int _endTrimMs = 0;

  // Options
  bool _muteAudio = false;
  double _playbackSpeed = 1.0;
  bool _isLoopingTrim = true;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    VideoPlayerController? controller;
    try {
      final file = await MediaScannerService.instance.getMediaFile(widget.item.localId);
      if (file == null || !await file.exists()) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Could not locate video file on device.';
          });
        }
        return;
      }

      _videoFile = file;
      controller = VideoPlayerController.file(file);
      await controller.initialize();

      _totalDurationMs = controller.value.duration.inMilliseconds;
      _startTrimMs = 0;
      _endTrimMs = _totalDurationMs;

      controller.addListener(_videoListener);

      if (mounted) {
        setState(() {
          _controller = controller;
          _isLoading = false;
        });
      } else {
        await controller.dispose();
      }
    } catch (e) {
      await controller?.dispose();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load video: $e';
        });
      }
    }
  }

  void _videoListener() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final currentPos = _controller!.value.position.inMilliseconds;

    // Loop within trimmed boundary
    if (_isLoopingTrim) {
      if (currentPos >= _endTrimMs) {
        _controller!.seekTo(Duration(milliseconds: _startTrimMs));
      } else if (currentPos < _startTrimMs) {
        _controller!.seekTo(Duration(milliseconds: _startTrimMs));
      }
    }

    if (mounted) setState(() {});
  }

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final millis = (d.inMilliseconds.remainder(1000) ~/ 100).toString();
    return '$minutes:$seconds.$millis';
  }

  Future<void> _exportTrimmedVideo() async {
    if (_isExporting || _videoFile == null) return;

    if (_endTrimMs <= _startTrimMs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid trim range: End time must be after start time.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);
    _controller?.pause();

    try {
      final savedItem = await MediaEditorService.instance.trimAndSaveVideo(
        sourceFilePath: _videoFile!.path,
        startMs: _startTrimMs,
        endMs: _endTrimMs,
        muteAudio: _muteAudio,
        originalFileName: widget.item.fileName,
      );

      if (mounted) {
        setState(() => _isExporting = false);
        if (savedItem != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Trimmed video saved to gallery & queued for backup!'),
              backgroundColor: AppTheme.colors(context).accentGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop(savedItem);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Export failed. Please check permissions and storage.'),
              backgroundColor: AppTheme.colors(context).accentRose,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: AppTheme.colors(context).accentRose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _exportAsGif() async {
    if (_isExporting || _videoFile == null) return;
    if (_endTrimMs <= _startTrimMs) return;

    setState(() => _isExporting = true);
    _controller?.pause();

    try {
      final savedItem = await MediaEditorService.instance.exportVideoAsGif(
        sourceFilePath: _videoFile!.path,
        startMs: _startTrimMs,
        endMs: _endTrimMs,
        originalFileName: widget.item.fileName,
      );

      if (mounted) {
        setState(() => _isExporting = false);
        if (savedItem != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Animated GIF saved directly to DCIM folder!'),
              backgroundColor: AppTheme.colors(context).accentGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop(savedItem);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to export GIF.'),
              backgroundColor: AppTheme.colors(context).accentRose,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GIF error: $e'),
            backgroundColor: AppTheme.colors(context).accentRose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);

    const systemOverlay = SystemUiOverlayStyle(
      statusBarColor: Color(0xFF000000),
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF000000),
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Color(0xFF000000),
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    );

    if (_isLoading) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: systemOverlay,
        child: Scaffold(
          backgroundColor: c.bg,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: c.primary),
                const SizedBox(height: 16),
                Text('Loading video...', style: TextStyle(color: c.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null || _controller == null) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: systemOverlay,
        child: Scaffold(
          backgroundColor: c.bg,
          appBar: AppBar(backgroundColor: c.bg, elevation: 0),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _errorMessage ?? 'Unknown error',
                style: TextStyle(color: c.accentRose, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    final isPlaying = _controller!.value.isPlaying;
    final trimmedDurationMs = math.max(0, _endTrimMs - _startTrimMs);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlay,
      child: Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildTopBar(c),

            // Video Player Center Viewport
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  ),

                  // Play/Pause Tap Target Overlay
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      setState(() {
                        if (isPlaying) {
                          _controller!.pause();
                        } else {
                          final pos = _controller!.value.position.inMilliseconds;
                          if (pos >= _endTrimMs || pos < _startTrimMs) {
                            _controller!.seekTo(Duration(milliseconds: _startTrimMs));
                          }
                          _controller!.play();
                        }
                      });
                    },
                    child: AnimatedOpacity(
                      opacity: isPlaying ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24, width: 1),
                            ),
                            child: Icon(
                              isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Video Controls & Trimmer Panel
            _buildBottomControls(c, trimmedDurationMs),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildTopBar(AppThemeColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        border: Border(bottom: BorderSide(color: c.glassBorderSubtle, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minSize: 0,
                onPressed: _isExporting ? null : _exportAsGif,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'GIF',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 0,
                onPressed: _isExporting ? null : _exportTrimmedVideo,
                child: _isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: AppTheme.appleYellow, strokeWidth: 2),
                      )
                    : const Text(
                        'Done',
                        style: TextStyle(
                          color: AppTheme.appleYellow,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(AppThemeColors c, int trimmedDurationMs) {
    final currentPos = _controller!.value.position.inMilliseconds;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        border: Border(top: BorderSide(color: c.glassBorderSubtle, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Duration info badge row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trimmed: ${_formatDuration(trimmedDurationMs)}',
                style: const TextStyle(
                  color: AppTheme.appleYellow,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                'Original: ${_formatDuration(_totalDurationMs)}',
                style: TextStyle(color: c.textTertiary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Visual Timeline Trimmer with RangeSlider (Apple Yellow framed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.appleYellow.withOpacity(0.6), width: 1.5),
            ),
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 9),
                    activeTrackColor: AppTheme.appleYellow,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: AppTheme.appleYellow,
                    trackHeight: 6,
                    overlayColor: AppTheme.appleYellow.withOpacity(0.2),
                  ),
                  child: RangeSlider(
                    values: RangeValues(
                      _startTrimMs.toDouble().clamp(0.0, _totalDurationMs.toDouble()),
                      _endTrimMs.toDouble().clamp(0.0, _totalDurationMs.toDouble()),
                    ),
                    min: 0.0,
                    max: math.max(1.0, _totalDurationMs.toDouble()),
                    onChanged: (RangeValues values) {
                      setState(() {
                        _startTrimMs = values.start.toInt();
                        _endTrimMs = values.end.toInt();
                      });
                      _controller?.seekTo(Duration(milliseconds: _startTrimMs));
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Start: ${_formatDuration(_startTrimMs)}',
                      style: TextStyle(color: c.textSecondary, fontSize: 11),
                    ),
                    Text(
                      'Play: ${_formatDuration(currentPos)}',
                      style: TextStyle(color: c.primaryLight, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'End: ${_formatDuration(_endTrimMs)}',
                      style: TextStyle(color: c.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Options Toolbar: Mute Audio, Speed, Loop
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Mute Audio Toggle
              GestureDetector(
                onTap: () {
                  setState(() {
                    _muteAudio = !_muteAudio;
                    _controller?.setVolume(_muteAudio ? 0.0 : 1.0);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _muteAudio ? c.accentRose.withOpacity(0.2) : c.surfaceGlassFloating,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _muteAudio ? c.accentRose : c.glassBorder,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _muteAudio ? Icons.volume_off_outlined : Icons.volume_up_outlined,
                        color: _muteAudio ? c.accentRose : c.textPrimary,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _muteAudio ? 'Muted' : 'Audio On',
                        style: TextStyle(
                          color: _muteAudio ? c.accentRose : c.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Playback Speed Toggle
              PopupMenuButton<double>(
                initialValue: _playbackSpeed,
                onSelected: (speed) {
                  setState(() {
                    _playbackSpeed = speed;
                    _controller?.setPlaybackSpeed(speed);
                  });
                },
                color: c.surfaceElevated,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 0.5, child: Text('0.5x Speed')),
                  const PopupMenuItem(value: 1.0, child: Text('1.0x (Normal)')),
                  const PopupMenuItem(value: 1.5, child: Text('1.5x Speed')),
                  const PopupMenuItem(value: 2.0, child: Text('2.0x Speed')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _playbackSpeed != 1.0 ? c.primary.withOpacity(0.2) : c.surfaceGlassFloating,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _playbackSpeed != 1.0 ? c.primary : c.glassBorder,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.speed_outlined, color: c.textPrimary, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${_playbackSpeed}x',
                        style: TextStyle(color: c.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),

              // Loop Toggle
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isLoopingTrim = !_isLoopingTrim;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isLoopingTrim ? c.primary.withOpacity(0.2) : c.surfaceGlassFloating,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isLoopingTrim ? c.primary : c.glassBorder,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.repeat_outlined,
                        color: _isLoopingTrim ? c.primary : c.textTertiary,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Loop',
                        style: TextStyle(
                          color: _isLoopingTrim ? c.primary : c.textTertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
