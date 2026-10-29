import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Liquidmorphism 3D Touch Card:
/// Responds to touch with authentic organic spring physics, real-time dynamic
/// pointer tracking for specular light refraction, directional liquid shadow casting,
/// and subtle resting vitality.
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
    this.maxTiltAngle = 0.08, // ~4.6 degrees
    this.pressScale = 0.965,
    this.enableShine = true,
    this.isSelected = false,
    this.glowColor,
  });

  @override
  State<ThreeDTouchCard> createState() => _ThreeDTouchCardState();
}

class _ThreeDTouchCardState extends State<ThreeDTouchCard>
    with TickerProviderStateMixin {
  late AnimationController _pressAnimController;
  late Animation<double> _scaleAnimation;

  // Spring animation for smooth tilt reset
  late AnimationController _tiltSpringController;
  late Animation<double> _tiltXAnimation;
  late Animation<double> _tiltYAnimation;

  double _targetTiltX = 0.0;
  double _targetTiltY = 0.0;
  double _currentTiltX = 0.0;
  double _currentTiltY = 0.0;
  double _shineX = 0.5;
  double _shineY = 0.5;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    _pressAnimController = AnimationController(
      vsync: this,
      duration: AppTheme.motionFast,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.pressScale).animate(
      CurvedAnimation(parent: _pressAnimController, curve: AppTheme.liquidSnap),
    );

    _tiltSpringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _tiltXAnimation = const AlwaysStoppedAnimation(0.0);
    _tiltYAnimation = const AlwaysStoppedAnimation(0.0);
  }

  @override
  void dispose() {
    _pressAnimController.dispose();
    _tiltSpringController.dispose();
    super.dispose();
  }

  void _updateTouchCoordinates(Offset localPosition, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final nx = ((localPosition.dx / size.width) * 2 - 1).clamp(-1.0, 1.0);
    final ny = ((localPosition.dy / size.height) * 2 - 1).clamp(-1.0, 1.0);

    setState(() {
      _targetTiltX = -ny * widget.maxTiltAngle;
      _targetTiltY = nx * widget.maxTiltAngle;
      _currentTiltX = _targetTiltX;
      _currentTiltY = _targetTiltY;
      _shineX = (localPosition.dx / size.width).clamp(0.0, 1.0);
      _shineY = (localPosition.dy / size.height).clamp(0.0, 1.0);
    });
  }

  void _handlePointerDown(PointerDownEvent details, BoxConstraints constraints) {
    _isPressed = true;
    _tiltSpringController.stop();
    _updateTouchCoordinates(details.localPosition, Size(constraints.maxWidth, constraints.maxHeight));
    _pressAnimController.forward();
  }

  void _handlePointerMove(PointerMoveEvent details, BoxConstraints constraints) {
    if (!_isPressed) return;
    _updateTouchCoordinates(details.localPosition, Size(constraints.maxWidth, constraints.maxHeight));
  }

  void _handlePointerUpOrCancel() {
    if (!_isPressed) return;
    _isPressed = false;

    // Animate smoothly back to equilibrium with liquid spring physics
    _tiltXAnimation = Tween<double>(begin: _currentTiltX, end: 0.0).animate(
      CurvedAnimation(parent: _tiltSpringController, curve: AppTheme.liquidSpring),
    );
    _tiltYAnimation = Tween<double>(begin: _currentTiltY, end: 0.0).animate(
      CurvedAnimation(parent: _tiltSpringController, curve: AppTheme.liquidSpring),
    );

    _tiltSpringController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _currentTiltX = 0.0;
          _currentTiltY = 0.0;
        });
      }
    });

    _pressAnimController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final radius = widget.borderRadius ?? BorderRadius.circular(20);
    final activeGlow = widget.glowColor ?? c.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          onPointerDown: (e) => _handlePointerDown(e, constraints),
          onPointerMove: (e) => _handlePointerMove(e, constraints),
          onPointerUp: (_) => _handlePointerUpOrCancel(),
          onPointerCancel: (_) => _handlePointerUpOrCancel(),
          child: GestureDetector(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            behavior: HitTestBehavior.opaque,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _pressAnimController,
                _tiltSpringController,
              ]),
              child: widget.child,
              builder: (context, cachedChild) {
                // Effective tilt angles
                final effTiltX = _isPressed
                    ? _currentTiltX
                    : _tiltXAnimation.value;
                final effTiltY = _isPressed
                    ? _currentTiltY
                    : _tiltYAnimation.value;

                final pressScale = _scaleAnimation.value;

                // 3D Perspective Matrix Transformation
                final transform = Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateX(effTiltX)
                  ..rotateY(effTiltY)
                  ..scale(pressScale);

                // Morphing directional shadow based on tilt angles
                final shadowOffsetX = -effTiltY * 60;
                final shadowOffsetY = (effTiltX * 60) + (_isPressed ? 4.0 : 8.0);
                final shadowBlur = _isPressed ? 14.0 : 22.0;

                return Transform(
                  transform: transform,
                  alignment: FractionalOffset.center,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      boxShadow: [
                        // Dynamic directional shadow opposing tilt angle
                        BoxShadow(
                          color: Colors.black.withOpacity(c.isDark ? 0.38 : 0.12),
                          blurRadius: shadowBlur,
                          offset: Offset(shadowOffsetX, shadowOffsetY),
                          spreadRadius: _isPressed ? -2 : 0,
                        ),
                        // Ambient colored glow
                        if (widget.isSelected || _isPressed)
                          BoxShadow(
                            color: activeGlow.withOpacity(_isPressed ? 0.28 : 0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.passthrough,
                      children: [
                        // Main Child
                        cachedChild!,

                        // Liquid Refractive Specular Glare (Dynamic tracking touch)
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
                                      radius: 0.85,
                                      colors: [
                                        Colors.white.withOpacity(c.isDark ? 0.28 : 0.38),
                                        Colors.white.withOpacity(c.isDark ? 0.08 : 0.14),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.40, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Selection Liquid Ripple & Border
                        if (widget.isSelected)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: radius,
                                  border: Border.all(
                                    color: activeGlow,
                                    width: 2.4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: activeGlow.withOpacity(0.40),
                                      blurRadius: 12,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
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
          ),
        );
      },
    );
  }
}
