import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Motion Primitives 3D Touch Card:
/// Responds to touch with authentic 3D perspective tilt, elevation depression,
/// and dynamic specular light sheen reflection.
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
    this.maxTiltAngle = 0.07, // in radians (~4 degrees)
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
      duration: AppTheme.motionFast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.pressScale).animate(
      CurvedAnimation(parent: _animController, curve: AppTheme.motionCurve),
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
    final c = AppTheme.colors(context);
    final radius = widget.borderRadius ?? BorderRadius.circular(16);
    final activeGlow = widget.glowColor ?? c.primary;

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
              child: widget.child, // Caches child RenderObject
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
                      // Base child
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
                                    radius: 0.95,
                                    colors: [
                                      Colors.white.withOpacity(c.isDark ? 0.22 : 0.35),
                                      Colors.white.withOpacity(c.isDark ? 0.05 : 0.10),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.45, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Selection Border & Colored Glow
                      if (widget.isSelected)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: radius,
                                border: Border.all(
                                  color: activeGlow,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: activeGlow.withOpacity(0.40),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
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
