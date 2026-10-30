import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Haikei & Liquidmorphism Living Canvas Background:
/// Emulates organic liquid physics with multi-tempo Fibonacci phase rhythms (8s, 13s, 21s),
/// chromatic light dispersion, fluid metaball-like merging blobs, layered wave contours,
/// and subtle optical texture.
class HaikeiBackground extends StatefulWidget {
  final Widget? child;
  const HaikeiBackground({super.key, this.child});

  @override
  State<HaikeiBackground> createState() => _HaikeiBackgroundState();
}

class _HaikeiBackgroundState extends State<HaikeiBackground>
    with TickerProviderStateMixin {
  // Fibonacci-inspired multi-tempo animation controllers for organic non-repeating flow
  late AnimationController _fastController; // 8s
  late AnimationController _midController;  // 13s
  late AnimationController _slowController; // 21s

  @override
  void initState() {
    super.initState();
    _fastController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _midController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 13),
    )..repeat();

    _slowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 21),
    )..repeat();
  }

  @override
  void dispose() {
    _fastController.dispose();
    _midController.dispose();
    _slowController.dispose();
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

        // Animated Liquidmorphism Living Canvas
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _fastController,
                _midController,
                _slowController,
              ]),
              builder: (context, _) {
                return CustomPaint(
                  painter: _LiquidmorphicCanvasPainter(
                    fastPhase: _fastController.value * 2 * math.pi,
                    midPhase: _midController.value * 2 * math.pi,
                    slowPhase: _slowController.value * 2 * math.pi,
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

class _LiquidmorphicCanvasPainter extends CustomPainter {
  final double fastPhase;
  final double midPhase;
  final double slowPhase;
  final AppThemeColors colors;

  _LiquidmorphicCanvasPainter({
    required this.fastPhase,
    required this.midPhase,
    required this.slowPhase,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final isDark = colors.isDark;
    final paint = Paint()..isAntiAlias = true;

    // Harmonic wave vectors
    final sinF = math.sin(fastPhase);
    final cosF = math.cos(fastPhase);
    final sinM = math.sin(midPhase);
    final cosM = math.cos(midPhase);
    final sinS = math.sin(slowPhase);
    final cosS = math.cos(slowPhase);

    // ─────────────────────────────────────────────────────────────
    // 1. ORGANIC LIQUID METABALL BLOBS WITH SUBTLE AMBIENT BLUE/VIOLET LIGHTING
    // ─────────────────────────────────────────────────────────────

    // --- Blob 1: Top-Right Electric Blue Ambient Glow ---
    final b1Radius = size.width * (0.46 + 0.05 * sinM);
    final b1Center = Offset(
      size.width * 0.82 + 35 * cosF,
      size.height * 0.14 + 30 * sinM,
    );
    // Ambient Blue refraction halo
    final b1DispersionCenter = b1Center + Offset(12 * cosF, 10 * sinM);
    paint.shader = RadialGradient(
      colors: [
        colors.accent.withOpacity(0.18), // Ambient Blue #263F73
        Colors.transparent,
      ],
      stops: const [0.0, 0.75],
    ).createShader(Rect.fromCircle(center: b1DispersionCenter, radius: b1Radius * 1.15));
    canvas.drawCircle(b1DispersionCenter, b1Radius * 1.15, paint);

    // Primary Electric Blue Core
    paint.shader = RadialGradient(
      colors: [
        colors.primary.withOpacity(0.16), // Electric Blue #477BFF
        colors.primaryLight.withOpacity(0.06), // Ice Blue #91B7FF
        Colors.transparent,
      ],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(Rect.fromCircle(center: b1Center, radius: b1Radius));
    canvas.drawCircle(b1Center, b1Radius, paint);

    // --- Blob 2: Mid-Left Violet Highlight Ambient Glow ---
    final b2Radius = size.width * (0.48 + 0.06 * cosS);
    final b2Center = Offset(
      size.width * 0.12 + 38 * sinM,
      size.height * 0.45 + 42 * cosF,
    );
    // Subtle Violet dispersion halo
    final b2DispersionCenter = b2Center + Offset(-10 * sinS, 8 * cosF);
    paint.shader = RadialGradient(
      colors: [
        colors.secondary.withOpacity(0.10), // Violet Highlight #8067FF
        Colors.transparent,
      ],
      stops: const [0.0, 0.70],
    ).createShader(Rect.fromCircle(center: b2DispersionCenter, radius: b2Radius * 1.12));
    canvas.drawCircle(b2DispersionCenter, b2Radius * 1.12, paint);

    // Primary Violet Core
    paint.shader = RadialGradient(
      colors: [
        colors.secondary.withOpacity(0.14), // Violet Highlight #8067FF
        colors.accent.withOpacity(0.06), // Ambient Blue #263F73
        Colors.transparent,
      ],
      stops: const [0.0, 0.48, 1.0],
    ).createShader(Rect.fromCircle(center: b2Center, radius: b2Radius));
    canvas.drawCircle(b2Center, b2Radius, paint);

    // --- Blob 3: Bottom-Right Deep Ambient Blue ---
    final b3Radius = size.width * (0.50 + 0.05 * sinS);
    final b3Center = Offset(
      size.width * 0.86 + 28 * cosM,
      size.height * 0.82 + 36 * sinF,
    );
    paint.shader = RadialGradient(
      colors: [
        colors.accent.withOpacity(0.20), // Ambient Blue #263F73
        colors.primary.withOpacity(0.06), // Electric Blue #477BFF
        Colors.transparent,
      ],
      stops: const [0.0, 0.52, 1.0],
    ).createShader(Rect.fromCircle(center: b3Center, radius: b3Radius));
    canvas.drawCircle(b3Center, b3Radius, paint);

    // --- Blob 4: Center-Left Ice Blue Soft Ambient Glow ---
    final b4Radius = size.width * (0.36 + 0.04 * cosF);
    final b4Center = Offset(
      size.width * 0.42 + 30 * sinS,
      size.height * 0.68 + 28 * cosM,
    );
    paint.shader = RadialGradient(
      colors: [
        colors.primaryLight.withOpacity(0.08), // Ice Blue #91B7FF
        colors.accent.withOpacity(0.05), // Ambient Blue #263F73
        Colors.transparent,
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Rect.fromCircle(center: b4Center, radius: b4Radius));
    canvas.drawCircle(b4Center, b4Radius, paint);

    // ─────────────────────────────────────────────────────────────
    // 2. LIQUID METABALL FUSION BRIDGE (Droplet snapping simulation)
    // ─────────────────────────────────────────────────────────────
    final bridgeVector = b4Center - b2Center;
    final bridgeDist = bridgeVector.distance;
    if (bridgeDist < (b2Radius + b4Radius) * 0.95) {
      final midPoint = (b2Center + b4Center) / 2;
      final bridgeRadius = (b2Radius + b4Radius) * 0.32;
      paint.shader = RadialGradient(
        colors: [
          colors.secondary.withOpacity(0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: midPoint, radius: bridgeRadius));
      canvas.drawCircle(midPoint, bridgeRadius, paint);
    }

    // ─────────────────────────────────────────────────────────────
    // 3. LAYERED PARALLAX LIQUID WAVE CONTOURS
    // ─────────────────────────────────────────────────────────────
    _drawLiquidContourWave(
      canvas,
      size,
      yFraction: 0.18,
      amplitude: 24,
      phase: fastPhase,
      color: colors.primaryLight.withOpacity(0.035),
      strokeWidth: 1.0,
    );

    _drawLiquidContourWave(
      canvas,
      size,
      yFraction: 0.42,
      amplitude: 18,
      phase: midPhase * 0.8,
      color: colors.secondary.withOpacity(0.025),
      strokeWidth: 0.8,
    );

    _drawLiquidContourWave(
      canvas,
      size,
      yFraction: 0.68,
      amplitude: 26,
      phase: slowPhase * 1.2,
      color: colors.accent.withOpacity(0.030),
      strokeWidth: 1.0,
    );

    // ─────────────────────────────────────────────────────────────
    // 4. SUBTLE MATERIAL GRAIN OVERLAY (Prevents digital banding)
    // ─────────────────────────────────────────────────────────────
    _drawSubtleGrain(canvas, size, isDark);
  }

  void _drawLiquidContourWave(
    Canvas canvas,
    Size size, {
    required double yFraction,
    required double amplitude,
    required double phase,
    required Color color,
    required double strokeWidth,
  }) {
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color
      ..isAntiAlias = true;

    final path = Path();
    final yBase = size.height * yFraction;

    path.moveTo(0, yBase + amplitude * math.sin(phase));
    path.cubicTo(
      size.width * 0.30,
      yBase - amplitude * 1.3 * math.cos(phase * 0.9),
      size.width * 0.68,
      yBase + amplitude * 1.2 * math.sin(phase * 1.1),
      size.width,
      yBase - amplitude * 0.8 * math.cos(phase),
    );

    canvas.drawPath(path, wavePaint);
  }

  void _drawSubtleGrain(Canvas canvas, Size size, bool isDark) {
    final dotPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(isDark ? 0.018 : 0.012)
      ..style = PaintingStyle.fill;

    // Deterministic pseudo-random grid sampling to prevent CPU spikes
    const step = 28.0;
    for (double x = 12; x < size.width; x += step) {
      for (double y = 14; y < size.height; y += step) {
        final hash = ((x * 37.0 + y * 71.0) % 17.0) / 17.0;
        if (hash > 0.6) {
          canvas.drawCircle(Offset(x + hash * 6, y + hash * 4), 0.75, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LiquidmorphicCanvasPainter oldDelegate) {
    return oldDelegate.fastPhase != fastPhase ||
        oldDelegate.midPhase != midPhase ||
        oldDelegate.slowPhase != slowPhase ||
        oldDelegate.colors != colors;
  }
}
