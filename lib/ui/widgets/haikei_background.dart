import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Haikei-inspired animated organic fluid background.
/// Renders dynamic breathing mesh orbs and layered vector contours that drift
/// smoothly behind 3D glassmorphic surfaces, creating optical refraction and depth.
class HaikeiBackground extends StatefulWidget {
  final Widget? child;
  const HaikeiBackground({super.key, this.child});

  @override
  State<HaikeiBackground> createState() => _HaikeiBackgroundState();
}

class _HaikeiBackgroundState extends State<HaikeiBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
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

        // Animated Haikei Organic Blobs & Wave Layers
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value * 2 * math.pi;
                return CustomPaint(
                  painter: _HaikeiCanvasPainter(
                    progress: t,
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

class _HaikeiCanvasPainter extends CustomPainter {
  final double progress;
  final AppThemeColors colors;

  _HaikeiCanvasPainter({
    required this.progress,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final isDark = colors.isDark;

    // Phase shifts for organic breathing & orbital drifting
    final sin1 = math.sin(progress);
    final cos1 = math.cos(progress);
    final sin2 = math.sin(progress * 1.3 + 1.2);
    final cos2 = math.cos(progress * 0.9 + 2.1);
    final sin3 = math.sin(progress * 0.7 + 3.4);

    final paint = Paint()..isAntiAlias = true;

    // --- Blob 1: Top-Right Sapphire / Azure Orb ---
    final b1Radius = size.width * (0.42 + 0.05 * sin1);
    final b1Center = Offset(
      size.width * 0.85 + 40 * cos1,
      size.height * 0.12 + 35 * sin2,
    );
    final b1Color = isDark
        ? colors.primary.withOpacity(0.18)
        : colors.primary.withOpacity(0.15);
    final b1Accent = isDark
        ? colors.accent.withOpacity(0.08)
        : colors.accent.withOpacity(0.06);

    paint.shader = RadialGradient(
      colors: [b1Color, b1Accent, Colors.transparent],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Rect.fromCircle(center: b1Center, radius: b1Radius));
    canvas.drawCircle(b1Center, b1Radius, paint);

    // --- Blob 2: Mid-Left Violet / Indigo Nebula ---
    final b2Radius = size.width * (0.45 + 0.06 * cos2);
    final b2Center = Offset(
      size.width * 0.10 + 35 * sin1,
      size.height * 0.44 + 45 * cos1,
    );
    final b2Color = isDark
        ? colors.secondary.withOpacity(0.16)
        : colors.secondary.withOpacity(0.13);
    final b2Accent = isDark
        ? colors.accentRose.withOpacity(0.06)
        : colors.accentRose.withOpacity(0.04);

    paint.shader = RadialGradient(
      colors: [b2Color, b2Accent, Colors.transparent],
      stops: const [0.0, 0.52, 1.0],
    ).createShader(Rect.fromCircle(center: b2Center, radius: b2Radius));
    canvas.drawCircle(b2Center, b2Radius, paint);

    // --- Blob 3: Bottom-Right Neon Cyan / Aquamarine Orb ---
    final b3Radius = size.width * (0.48 + 0.05 * sin3);
    final b3Center = Offset(
      size.width * 0.88 + 30 * cos2,
      size.height * 0.80 + 40 * sin1,
    );
    final b3Color = isDark
        ? colors.accent.withOpacity(0.14)
        : colors.accent.withOpacity(0.12);
    final b3Accent = isDark
        ? colors.primary.withOpacity(0.05)
        : colors.primary.withOpacity(0.04);

    paint.shader = RadialGradient(
      colors: [b3Color, b3Accent, Colors.transparent],
      stops: const [0.0, 0.58, 1.0],
    ).createShader(Rect.fromCircle(center: b3Center, radius: b3Radius));
    canvas.drawCircle(b3Center, b3Radius, paint);

    // --- Blob 4: Center-Left Soft Emerald Accent Halo ---
    final b4Radius = size.width * (0.32 + 0.04 * cos1);
    final b4Center = Offset(
      size.width * 0.35 + 25 * sin3,
      size.height * 0.72 + 30 * cos2,
    );
    final b4Color = isDark
        ? colors.accentGreen.withOpacity(0.07)
        : colors.accentGreen.withOpacity(0.08);

    paint.shader = RadialGradient(
      colors: [b4Color, Colors.transparent],
      stops: const [0.0, 1.0],
    ).createShader(Rect.fromCircle(center: b4Center, radius: b4Radius));
    canvas.drawCircle(b4Center, b4Radius, paint);

    // --- Haikei Organic Layered Flow Waves (subtle vector contours) ---
    _drawHaikeiWave(canvas, size, progress, colors);
  }

  void _drawHaikeiWave(Canvas canvas, Size size, double p, AppThemeColors c) {
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    final isDark = c.isDark;
    final waveColor = isDark
        ? Colors.white.withOpacity(0.035)
        : c.primary.withOpacity(0.045);

    wavePaint.color = waveColor;

    // Organic top flowing wave
    final path1 = Path();
    final y1 = size.height * 0.18;
    path1.moveTo(0, y1 + 20 * math.sin(p));
    path1.cubicTo(
      size.width * 0.28,
      y1 - 30 * math.cos(p * 0.8),
      size.width * 0.65,
      y1 + 35 * math.sin(p * 0.9),
      size.width,
      y1 - 15 * math.cos(p),
    );
    canvas.drawPath(path1, wavePaint);

    // Organic mid-bottom flowing wave
    final path2 = Path();
    final y2 = size.height * 0.68;
    path2.moveTo(0, y2 - 25 * math.cos(p * 0.7));
    path2.cubicTo(
      size.width * 0.35,
      y2 + 35 * math.sin(p * 1.1),
      size.width * 0.72,
      y2 - 25 * math.cos(p * 0.8),
      size.width,
      y2 + 20 * math.sin(p),
    );
    canvas.drawPath(path2, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _HaikeiCanvasPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.colors != colors;
  }
}
