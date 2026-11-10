import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Apple Photos Ambient Living Canvas:
/// Delivers an authentic Apple canvas experience: deep pure OLED black in dark mode
/// and pristine iOS light grouped background in light mode, with whisper-soft,
/// subtle ambient luminous diffusion that makes photo libraries pop without visual distraction.
class HaikeiBackground extends StatefulWidget {
  final Widget? child;
  const HaikeiBackground({super.key, this.child});

  @override
  State<HaikeiBackground> createState() => _HaikeiBackgroundState();
}

class _HaikeiBackgroundState extends State<HaikeiBackground>
    with TickerProviderStateMixin {
  late AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Solid theme canvas base
        ColoredBox(color: c.bg),

        // Apple Ambient Light Dispersion (subtle and non-intrusive)
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _ambientController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _AppleAmbientCanvasPainter(
                    phase: _ambientController.value * 2 * math.pi,
                    colors: c,
                  ),
                );
              },
            ),
          ),
        ),

        // Foreground content
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _AppleAmbientCanvasPainter extends CustomPainter {
  final double phase;
  final AppThemeColors colors;

  _AppleAmbientCanvasPainter({
    required this.phase,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final isDark = colors.isDark;
    final paint = Paint()..isAntiAlias = true;

    final sinP = math.sin(phase);
    final cosP = math.cos(phase);

    if (isDark) {
      // ─── APPLE OLED AMBIENT LIGHTING (Dark Mode) ───────────────────
      // Very soft, elegant luminous glows in Apple Blue & Indigo that accent the OLED canvas

      // Top-right soft Apple Blue ambient glow
      final r1 = size.width * (0.50 + 0.04 * sinP);
      final c1 = Offset(size.width * 0.85 + 20 * cosP, size.height * 0.12 + 15 * sinP);
      paint.shader = RadialGradient(
        colors: [
          colors.primary.withOpacity(0.06),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: c1, radius: r1));
      canvas.drawCircle(c1, r1, paint);

      // Mid-left subtle Indigo ambient glow
      final r2 = size.width * (0.45 + 0.03 * cosP);
      final c2 = Offset(size.width * 0.10 + 15 * sinP, size.height * 0.55 + 20 * cosP);
      paint.shader = RadialGradient(
        colors: [
          colors.secondary.withOpacity(0.04),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: c2, radius: r2));
      canvas.drawCircle(c2, r2, paint);

      // Bottom-right subtle ambient light
      final r3 = size.width * (0.42 + 0.03 * sinP);
      final c3 = Offset(size.width * 0.80 - 15 * cosP, size.height * 0.88 - 15 * sinP);
      paint.shader = RadialGradient(
        colors: [
          colors.primaryLight.withOpacity(0.035),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: c3, radius: r3));
      canvas.drawCircle(c3, r3, paint);
    } else {
      // ─── APPLE PRISTINE DAYLIGHT CANVAS (Light Mode) ───────────────
      // Clean white canvas with faint iOS ambient highlights
      final r1 = size.width * (0.60 + 0.04 * sinP);
      final c1 = Offset(size.width * 0.90, size.height * 0.10);
      paint.shader = RadialGradient(
        colors: [
          colors.primary.withOpacity(0.03),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: c1, radius: r1));
      canvas.drawCircle(c1, r1, paint);

      final r2 = size.width * (0.50 + 0.03 * cosP);
      final c2 = Offset(size.width * 0.10, size.height * 0.80);
      paint.shader = RadialGradient(
        colors: [
          colors.secondary.withOpacity(0.02),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: c2, radius: r2));
      canvas.drawCircle(c2, r2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AppleAmbientCanvasPainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.colors != colors;
  }
}
