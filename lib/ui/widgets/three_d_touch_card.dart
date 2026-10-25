import 'package:flutter/material.dart';

/// An interactive widget that responds to touches and taps with genuine
/// 3D perspective tilt, elevation depression, and a dynamic specular shine reflection.
/// Designed for zero-rebuild overhead so child widgets never flicker or re-render.
class ThreeDTouchCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final double maxTiltAngle;
  final double pressScale;
  final bool enableShine;
  final bool isSelected;
  final Color? glowColor;

  const ThreeDTouchCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.maxTiltAngle = 0.08, // in radians (~4.5 degrees)
    this.pressScale = 0.965,
    this.enableShine = true,
    this.isSelected = false,
    this.glowColor,
  });

  @override
  State<ThreeDTouchCard> createState() => _ThreeDTouchCardState();
}

class _ThreeDTouchCardState extends State<ThreeDTouchCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  double _tiltX = 0.0;
  double _tiltY = 0.0;
  double _shineX = 0.5;
  double _shineY = 0.5;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.pressScale).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent details, BoxConstraints constraints) {
    final w = constraints.maxWidth;
    final h = constraints.maxHeight;
    if (w <= 0 || h <= 0) return;

    final nx = ((details.localPosition.dx / w) * 2 - 1).clamp(-1.0, 1.0);
    final ny = ((details.localPosition.dy / h) * 2 - 1).clamp(-1.0, 1.0);

    setState(() {
      _isPressed = true;
      _tiltX = -ny * widget.maxTiltAngle;
      _tiltY = nx * widget.maxTiltAngle;
      _shineX = (details.localPosition.dx / w).clamp(0.0, 1.0);
      _shineY = (details.localPosition.dy / h).clamp(0.0, 1.0);
    });
    _animController.forward();
  }

  void _handlePointerUpOrCancel() {
    if (!_isPressed) return;
    setState(() {
      _isPressed = false;
      _tiltX = 0.0;
      _tiltY = 0.0;
    });
    _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(16);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          onPointerDown: (e) => _handlePointerDown(e, constraints),
          onPointerUp: (_) => _handlePointerUpOrCancel(),
          onPointerCancel: (_) => _handlePointerUpOrCancel(),
          child: GestureDetector(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            behavior: HitTestBehavior.opaque,
            child: AnimatedBuilder(
              animation: _animController,
              child: widget.child, // Crucial: caches child RenderObject so it never rebuilds or flickers
              builder: (context, cachedChild) {
                final scale = _scaleAnimation.value;
                final currentTiltX = _isPressed ? _tiltX : 0.0;
                final currentTiltY = _isPressed ? _tiltY : 0.0;

                // 3D perspective matrix
                final transform = Matrix4.identity()
                  ..setEntry(3, 2, 0.0014)
                  ..rotateX(currentTiltX)
                  ..rotateY(currentTiltY)
                  ..scale(scale);

                return Transform(
                  transform: transform,
                  alignment: FractionalOffset.center,
                  child: Stack(
                    fit: StackFit.passthrough,
                    children: [
                      // Cached base child (zero rebuild overhead)
                      cachedChild!,

                      // Specular Glare Overlay
                      if (widget.enableShine && _isPressed)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ClipRRect(
                              borderRadius: radius,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment(
                                      _shineX * 2 - 1,
                                      _shineY * 2 - 1,
                                    ),
                                    radius: 0.9,
                                    colors: [
                                      Colors.white.withOpacity(0.18),
                                      Colors.white.withOpacity(0.04),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.45, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Selection Border & Glow if marked selected
                      if (widget.isSelected)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: radius,
                                border: Border.all(
                                  color: widget.glowColor ?? const Color(0xFF00E5FF),
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
