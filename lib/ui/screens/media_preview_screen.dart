import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
import '../../providers/backup_provider.dart';
import '../../services/device_settings_helper.dart';
import '../../services/favorites_service.dart';
import '../../services/google_drive_service.dart';
import '../../services/media_scanner_service.dart';
import '../../services/vault_service.dart';
import '../widgets/move_to_folder_sheet.dart';
import 'photo_editor_screen.dart';
import 'video_editor_screen.dart';

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
    with TickerProviderStateMixin {
  late PageController _pageController;
  late List<MediaItem> _items;
  late int _currentIndex;
  bool _showControls = true;
  bool _isCoverMode = false;

  // Active video controller for video playback
  VideoPlayerController? _videoController;
  int? _activeVideoIndex;
  bool _isVideoInitialized = false;

  // Zoom controller for interactive viewer
  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _zoomAnimController;
  Animation<Matrix4>? _zoomAnimation;

  // Swipe-down-to-close drag tracking state
  double _dragOffsetY = 0.0;
  bool _isDraggingDown = false;
  double _pointerDownY = 0.0;
  double _pointerDownX = 0.0;
  DateTime _pointerDownTime = DateTime.now();
  int? _activePointerId;
  int _pointerCount = 0;

  late AnimationController _dismissAnimController;
  Animation<double>? _dismissAnimation;

  bool get _isZoomed {
    final matrix = _transformationController.value;
    return matrix.storage[0] > 1.05 || matrix.storage[5] > 1.05;
  }

  @override
  void initState() {
    super.initState();
    _items = List<MediaItem>.from(widget.items);
    _currentIndex =
        widget.initialIndex.clamp(0, _items.isEmpty ? 0 : _items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);

    // Initial system UI styling with solid dark navigation
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF000000),
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF000000),
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Color(0xFF000000),
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    ));

    _zoomAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _transformationController.value = _zoomAnimation!.value;
        }
      });

    _dismissAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        if (_dismissAnimation != null) {
          setState(() {
            _dragOffsetY = _dismissAnimation!.value;
          });
        }
      });

    if (_items.isNotEmpty) {
      _checkAndInitVideo(_currentIndex);
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    _dismissAnimController.dispose();
    _videoController?.dispose();
    _pageController.dispose();
    _zoomAnimController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerCount++;
    if (_pointerCount == 1 && !_isZoomed) {
      _activePointerId = event.pointer;
      _pointerDownY = event.position.dy;
      _pointerDownX = event.position.dx;
      _pointerDownTime = DateTime.now();
      _isDraggingDown = false;
    } else if (_pointerCount > 1 && _isDraggingDown) {
      _animateSnapBack();
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointerId || _pointerCount > 1 || _isZoomed) return;

    final dy = event.position.dy - _pointerDownY;
    final dx = event.position.dx - _pointerDownX;

    if (!_isDraggingDown) {
      // Must be moving predominantly downwards (angle > 45 degrees downwards)
      if (dy > 14 && dy > dx.abs() * 1.3) {
        setState(() {
          _isDraggingDown = true;
          _dragOffsetY = dy;
        });
      }
    } else {
      setState(() {
        // Smooth dampening if pulled upwards above rest
        _dragOffsetY = dy >= 0 ? dy : dy * 0.15;
      });
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _pointerCount = (_pointerCount - 1).clamp(0, 10);
    if (event.pointer == _activePointerId) {
      _activePointerId = null;
      if (_isDraggingDown) {
        final elapsedMs = DateTime.now().difference(_pointerDownTime).inMilliseconds;
        final velocityY = elapsedMs > 0 ? (_dragOffsetY / elapsedMs) * 1000 : 0.0;

        // Dismiss if dragged down > 90 logical px OR swiped/flicked downwards (> 400 px/sec)
        final bool shouldDismiss = _dragOffsetY > 90 || (velocityY > 400 && _dragOffsetY > 25);
        if (shouldDismiss) {
          _animateAndDismiss();
        } else {
          _animateSnapBack();
        }
      }
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointerCount = (_pointerCount - 1).clamp(0, 10);
    if (event.pointer == _activePointerId) {
      _activePointerId = null;
      if (_isDraggingDown) {
        _animateSnapBack();
      }
    }
  }

  void _animateAndDismiss() {
    if (!mounted) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    _videoController?.pause();
    final screenHeight = MediaQuery.of(context).size.height;
    _dismissAnimation = Tween<double>(
      begin: _dragOffsetY,
      end: screenHeight,
    ).animate(CurvedAnimation(
      parent: _dismissAnimController,
      curve: Curves.easeOutCubic,
    ));

    _dismissAnimController.forward(from: 0).then((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _animateSnapBack() {
    if (!mounted) return;
    _dismissAnimation = Tween<double>(
      begin: _dragOffsetY,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _dismissAnimController,
      curve: Curves.easeOutCubic,
    ));

    _dismissAnimController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _isDraggingDown = false;
          _dragOffsetY = 0.0;
        });
      }
    });
  }

  void _toggleControls() {
    if (_isDraggingDown) return;
    final nextState = !_showControls;
    setState(() {
      _showControls = nextState;
    });

    if (nextState) {
      // Re-enable system UI overlays when controls appear
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    } else {
      // Enter true immersive full screen: hides mobile status bar & back bar completely
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
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
        VideoPlayerController? controller;
        try {
          controller = VideoPlayerController.file(file);
          await controller.initialize();

          if (mounted && _currentIndex == index) {
            controller.setLooping(true);
            controller.addListener(() {
              if (mounted) setState(() {});
            });
            setState(() {
              _videoController = controller;
              _activeVideoIndex = index;
              _isVideoInitialized = true;
            });
          } else {
            // Screen was closed or user swiped to another page during initialization
            await controller.dispose();
          }
        } catch (e) {
          debugPrint('Error loading video: $e');
          await controller?.dispose();
        }
      }
    }
  }

  Future<void> _openEditorForCurrentItem() async {
    if (_items.isEmpty || _currentIndex >= _items.length) return;
    final currentItem = _items[_currentIndex];

    _videoController?.pause();

    MediaItem? editedItem;
    if (currentItem.mediaType == AppMediaType.video) {
      editedItem = await Navigator.of(context).push<MediaItem>(
        MaterialPageRoute(
          builder: (_) => VideoEditorScreen(item: currentItem),
        ),
      );
    } else {
      editedItem = await Navigator.of(context).push<MediaItem>(
        MaterialPageRoute(
          builder: (_) => PhotoEditorScreen(item: currentItem),
        ),
      );
    }

    if (editedItem != null && mounted) {
      setState(() {
        _items.insert(_currentIndex + 1, editedItem!);
      });
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _pageController.hasClients) {
          _pageController.animateToPage(
            _currentIndex + 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
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

  Future<void> _moveCurrentItem() async {
    if (_items.isEmpty) return;
    final item = _items[_currentIndex];
    final isVaultItem = VaultService.instance.isLockedInApp(item.localId) ||
        (item.localFilePath != null && item.localFilePath!.contains('.private_vault'));

    if (isVaultItem) {
      final confirm = await showCupertinoModalPopup<String>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: const Text('Restore Item'),
          message: Text('Restore "${item.fileName}" back to its original location?'),
          actions: [
            CupertinoActionSheetAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop('restore'),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.arrow_counterclockwise, size: 18),
                  SizedBox(width: 8),
                  Text('Restore to Same Place (Original)'),
                ],
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
        ),
      );
      if (confirm == 'restore' && mounted) {
        await VaultService.instance.moveOutOfVault([item]);
        if (mounted) {
          context.read<BackupProvider>().refreshData();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Restored "${item.fileName}" to original location'),
              duration: const Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pop();
        }
      }
      return;
    }

    final target = await MoveToFolderSheet.show(context, [item]);
    if (target != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Moved "${item.fileName}" to $target'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _confirmAndDeleteCurrentItem() async {
    if (_items.isEmpty) return;
    final item = _items[_currentIndex];

    final c = AppTheme.colors(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: AlertDialog(
          backgroundColor: c.surfaceGlass,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: c.glassBorder,
              width: 0.8,
            ),
          ),
          title: Row(
            children: [
              Icon(Icons.delete_forever_outlined, color: c.accentRose, size: 21),
              const SizedBox(width: 10),
              Text('Delete File?', style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "${item.fileName}" from device storage?',
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            backgroundColor: const Color(0xFF1A2230),
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
    final c = AppTheme.colors(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: c.isDark ? const Color(0xE61C1C1E) : const Color(0xF2FFFFFF),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(
                color: c.glassBorderSubtle,
                width: 0.5,
              ),
            ),
            padding: EdgeInsets.only(
              top: 10,
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: c.textTertiary.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Info',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: c.isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(CupertinoIcons.clear, color: c.textSecondary, size: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Apple Grouped Info Cards
            Row(
              children: [
                Expanded(
                  child: _buildDetailCard(
                    CupertinoIcons.viewfinder,
                    'Resolution',
                    item.formattedDimensions.isNotEmpty
                        ? item.formattedDimensions
                        : 'Standard',
                    c,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildDetailCard(
                    CupertinoIcons.chart_pie,
                    'File Size',
                    item.formattedSize,
                    c,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildDetailCard(
                    CupertinoIcons.folder,
                    'Album',
                    item.displayFolderName,
                    c,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildDetailCard(
                    CupertinoIcons.doc,
                    'Format',
                    item.mimeType.split('/').last.toUpperCase(),
                    c,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _buildDetailRow(CupertinoIcons.doc_text, 'File Name', item.fileName, c),
            _buildDetailRow(CupertinoIcons.calendar, 'Date Taken', df.format(item.createdAt), c),
            if (item.localFilePath != null)
              _buildDetailRow(CupertinoIcons.device_phone_portrait, 'Storage Path', item.localFilePath!, c),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  ),
);
}

  Widget _buildDetailCard(IconData icon, String title, String value, AppThemeColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: c.isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.glassBorderSubtle, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: c.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 14, color: c.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(color: c.textTertiary, fontSize: 10.5, letterSpacing: -0.1),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
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

  Widget _buildDetailRow(IconData icon, String label, String value, AppThemeColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c.textTertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: c.textTertiary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: c.textPrimary,
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

    final c = AppTheme.colors(context);
    final currentItem = _items[_currentIndex];
    final isVideo = currentItem.mediaType == AppMediaType.video;
    final isFavorite = FavoritesService.instance.isFavorite(currentItem.localId);

    // Dynamic swipe-down dismiss values
    final dragProgress = (_dragOffsetY.abs() / 280.0).clamp(0.0, 1.0);
    final bgOpacity = (1.0 - dragProgress * 0.9).clamp(0.0, 1.0);
    final contentScale = (1.0 - dragProgress * 0.14).clamp(0.86, 1.0);
    final controlsOpacity = _showControls ? (1.0 - dragProgress * 2.5).clamp(0.0, 1.0) : 0.0;

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
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
        },
        child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Dark Frosted Backdrop that smoothly fades out as dragged down
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withOpacity(bgOpacity),
              ),
            ),

            // 1. Swipeable Full-Screen PageView with Double-Tap Zoom & Downward Drag Transform
            Transform.translate(
              offset: Offset(0, _dragOffsetY),
              child: Transform.scale(
                scale: contentScale,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(dragProgress * 32.0),
                  child: GestureDetector(
                    onTap: _toggleControls,
                    onDoubleTapDown: _handleDoubleTapZoom,
                    onDoubleTap: () {},
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.only(
                        top: (_showControls && !_isDraggingDown)
                            ? math.max(MediaQuery.of(context).padding.top, 32.0) + 64.0
                            : 0.0,
                        bottom: (_showControls && !_isDraggingDown)
                            ? (isVideo
                                ? math.max(MediaQuery.of(context).padding.bottom, 16.0) + 130.0
                                : math.max(MediaQuery.of(context).padding.bottom, 16.0) + 88.0)
                            : 0.0,
                      ),
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _items.length,
                        onPageChanged: _onPageChanged,
                        physics: _isDraggingDown
                            ? const NeverScrollableScrollPhysics()
                            : const BouncingScrollPhysics(),
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
                  ),
                ),
              ),
            ),

          // 2. 3D Frosted Top Navigation Bar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            top: (_showControls && !_isDraggingDown) ? 0 : -140,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: controlsOpacity,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: EdgeInsets.only(
                      top: math.max(MediaQuery.of(context).padding.top, 32.0) + 8.0,
                      left: 10,
                      right: 14,
                      bottom: 12,
                    ),
                    decoration: BoxDecoration(
                      color: c.surfaceGlass,
                      border: Border(
                        bottom: BorderSide(
                          color: c.glassBorderSubtle,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          minSize: 0,
                          onPressed: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: c.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                              shape: BoxShape.circle,
                              border: Border.all(color: c.glassBorder, width: 0.5),
                            ),
                            child: Icon(CupertinoIcons.chevron_back, color: c.primary, size: 18),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('d MMMM yyyy').format(currentItem.createdAt),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                DateFormat('h:mm a').format(currentItem.createdAt),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.65),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minSize: 0,
                              onPressed: () {
                                setState(() {
                                  _isCoverMode = !_isCoverMode;
                                  _transformationController.value = Matrix4.identity();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: c.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: c.glassBorder, width: 0.5),
                                ),
                                child: Icon(
                                  _isCoverMode ? Icons.fit_screen_outlined : Icons.fullscreen_outlined,
                                  color: c.primary,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minSize: 0,
                              onPressed: _openEditorForCurrentItem,
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: c.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: c.glassBorder, width: 0.5),
                                ),
                                child: Icon(CupertinoIcons.pencil, color: c.primary, size: 18),
                              ),
                            ),
                            const SizedBox(width: 8),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minSize: 0,
                              onPressed: _showItemDetailsBottomSheet,
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: c.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: c.glassBorder, width: 0.5),
                                ),
                                child: Icon(CupertinoIcons.info_circle, color: c.primary, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Floating Rounded Bottom Toolbar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            bottom: (_showControls && !_isDraggingDown) ? 0 : -160,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: controlsOpacity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Video Scrubber (if video is currently active)
                  if (isVideo && _isVideoInitialized && _videoController != null)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: c.surfaceGlass,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: c.glassBorder, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _formatDuration(_videoController!.value.position),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: c.primary,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: Colors.white,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                trackHeight: 3.0,
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
                            style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 11),
                          ),
                        ],
                      ),
                    ),

                  // Floating Rounded Glassmorphic Action Navbar
                  Padding(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: math.max(MediaQuery.of(context).padding.bottom, 16.0) + 14.0,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(34),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: AppTheme.floatingNavbarDecoration(context: context),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              CupertinoButton(
                                padding: const EdgeInsets.all(8),
                                minSize: 0,
                                onPressed: _shareCurrentItem,
                                child: Icon(CupertinoIcons.share, color: c.primary, size: 20),
                              ),
                              CupertinoButton(
                                padding: const EdgeInsets.all(8),
                                minSize: 0,
                                onPressed: () async {
                                  await FavoritesService.instance.toggleFavorite(currentItem.localId);
                                  setState(() {});
                                },
                                child: Icon(
                                  isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                                  color: isFavorite ? c.accentRose : c.primary,
                                  size: 20,
                                ),
                              ),
                              CupertinoButton(
                                padding: const EdgeInsets.all(8),
                                minSize: 0,
                                onPressed: _openEditorForCurrentItem,
                                child: Icon(
                                  CupertinoIcons.slider_horizontal_3,
                                  color: c.primary,
                                  size: 20,
                                ),
                              ),
                              CupertinoButton(
                                padding: const EdgeInsets.all(8),
                                minSize: 0,
                                onPressed: _moveCurrentItem,
                                child: Icon(
                                  Icons.drive_file_move_outlined,
                                  color: c.primary,
                                  size: 20,
                                ),
                              ),
                              CupertinoButton(
                                padding: const EdgeInsets.all(8),
                                minSize: 0,
                                onPressed: _showItemDetailsBottomSheet,
                                child: Icon(CupertinoIcons.info, color: c.primary, size: 20),
                              ),
                              CupertinoButton(
                                padding: const EdgeInsets.all(8),
                                minSize: 0,
                                onPressed: _confirmAndDeleteCurrentItem,
                                child: Icon(CupertinoIcons.trash, color: c.accentRose, size: 20),
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
          // Solid Phone Navigation Bar Base (Pure Black)
          if (MediaQuery.of(context).padding.bottom > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: MediaQuery.of(context).padding.bottom,
              child: const ColoredBox(
                color: Color(0xFF000000),
              ),
            ),
        ],
      ),
    ),
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
      isDraggingDown: _isDraggingDown,
      isCoverMode: _isCoverMode,
    );
  }

  Widget _buildVideoPage(int index, MediaItem item) {
    if (_activeVideoIndex == index && _isVideoInitialized && _videoController != null) {
      return Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            _isCoverMode
                ? SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: _videoController!.value.size.width > 0
                            ? _videoController!.value.size.width
                            : 16,
                        height: _videoController!.value.size.height > 0
                            ? _videoController!.value.size.height
                            : 9,
                        child: VideoPlayer(_videoController!),
                      ),
                    ),
                  )
                : AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio > 0
                        ? _videoController!.value.aspectRatio
                        : 16 / 9,
                    child: VideoPlayer(_videoController!),
                  ),
            // Apple Photos Frosted Play Center Button
            if (!_videoController!.value.isPlaying)
              GestureDetector(
                onTap: () {
                  _videoController!.play();
                  setState(() {});
                },
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                          width: 1.0,
                        ),
                      ),
                      padding: const EdgeInsets.all(18),
                      child: const Icon(
                        CupertinoIcons.play_fill,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
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
            _isCoverMode
                ? SizedBox.expand(
                    child: Image.memory(
                      cachedBytes,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildMissingFileError(),
                    ),
                  )
                : Image.memory(
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
                  _isCoverMode
                      ? SizedBox.expand(
                          child: Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildMissingFileError(),
                          ),
                        )
                      : Image.memory(
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
              icon: const Icon(Icons.arrow_back, size: 15),
              label: const Text('Back to Gallery'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.darkCardBorder,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
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
  final bool isDraggingDown;
  final bool isCoverMode;

  const _FullImagePreviewPage({
    super.key,
    required this.item,
    required this.transformationController,
    required this.errorBuilder,
    this.isDraggingDown = false,
    this.isCoverMode = true,
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
      try {
        final f = File(widget.item.localFilePath!);
        if (await f.exists() && await f.length() > 0) {
          if (mounted) {
            setState(() {
              _resolvedFile = f;
            });
            return;
          }
        }
      } catch (_) {}
    }

    // 2. Resolve origin / full file via MediaScannerService
    try {
      final file = await MediaScannerService.instance.getMediaFile(widget.item.localId);
      if (file != null && await file.exists() && await file.length() > 0) {
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

    // 4. Cloud Fallback: Download from Google Drive if backed up!
    if (widget.item.driveFileId != null && widget.item.driveFileId!.isNotEmpty) {
      try {
        final cloudBytes = await GoogleDriveService.instance.downloadFileBytes(widget.item.driveFileId!);
        if (cloudBytes != null && cloudBytes.isNotEmpty) {
          if (mounted) {
            setState(() {
              _resolvedBytes = cloudBytes;
            });
            return;
          }
        }
      } catch (_) {}
    }

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
        panEnabled: !widget.isDraggingDown,
        scaleEnabled: !widget.isDraggingDown,
        child: Center(
          child: Hero(
            tag: 'media_tile_${widget.item.localId}',
            child: widget.isCoverMode
                ? SizedBox.expand(
                    child: Image.file(
                      _resolvedFile!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      alignment: Alignment.center,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) => widget.errorBuilder(),
                    ),
                  )
                : Image.file(
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
        panEnabled: !widget.isDraggingDown,
        scaleEnabled: !widget.isDraggingDown,
        child: Center(
          child: Hero(
            tag: 'media_tile_${widget.item.localId}',
            child: widget.isCoverMode
                ? SizedBox.expand(
                    child: Image.memory(
                      _resolvedBytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      alignment: Alignment.center,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) => widget.errorBuilder(),
                    ),
                  )
                : Image.memory(
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
        panEnabled: !widget.isDraggingDown,
        scaleEnabled: !widget.isDraggingDown,
        child: Center(
          child: Hero(
            tag: 'media_tile_${widget.item.localId}',
            child: widget.isCoverMode
                ? SizedBox.expand(
                    child: Image.memory(
                      cachedThumbnail,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      alignment: Alignment.center,
                      gaplessPlayback: true,
                    ),
                  )
                : Image.memory(
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
