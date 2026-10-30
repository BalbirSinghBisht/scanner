import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Luxury Cinematic Gallery Color Palette Tokens
/// Strict color system according to design specification
class AppThemeColors {
  final bool isDark;

  // Background & Canvas
  final Color bg;
  final Color bgSecondary;

  // Surfaces & Glass
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceGlass;
  final Color surfaceGlassFloating;
  final Color surfaceGlassInput;

  // Glass Specular Borders (dual-light bevel)
  final Color glassBorder;
  final Color glassBorderSpecular;
  final Color glassBorderSubtle;

  // High-contrast Typography
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  // Luxury Cinematic Brand Palette
  final Color primary;
  final Color primaryLight;
  final Color secondary;
  final Color accent;
  final Color accentGreen;
  final Color accentRose;
  final Color accentAmber;

  // Dedicated Glass & Overlay Tokens
  final Color glassOverlay;
  final Color strongGlassOverlay;
  final Color blueGlassHighlight;
  final Color glassShadow;

  const AppThemeColors({
    required this.isDark,
    required this.bg,
    required this.bgSecondary,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceGlass,
    required this.surfaceGlassFloating,
    required this.surfaceGlassInput,
    required this.glassBorder,
    required this.glassBorderSpecular,
    required this.glassBorderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.primary,
    required this.primaryLight,
    required this.secondary,
    required this.accent,
    required this.accentGreen,
    required this.accentRose,
    required this.accentAmber,
    required this.glassOverlay,
    required this.strongGlassOverlay,
    required this.blueGlassHighlight,
    required this.glassShadow,
  });
}

class AppTheme {
  // --- STRICT LUXURY CINEMATIC COLOR PALETTE ---
  // Background palette
  // Deep Background: #050609
  // Secondary Background: #0B0E14
  // Primary Surface: #10141D
  // Elevated Surface: #1A2230
  // Accent palette
  // Electric Blue: #477BFF
  // Ice Blue: #91B7FF
  // Violet Highlight: #8067FF
  // Ambient Blue: #263F73
  // Typography
  // Primary Text: #F8FAFF
  // Secondary Text: #A0AABD
  // Muted Text: #68758A
  // Borders and glass
  // Primary Border: #34435D
  // Subtle Border: #222D40
  // Glass Overlay: #FFFFFF12
  // Strong Glass Overlay: #FFFFFF20
  // Blue Glass Highlight: #477BFF26
  // Glass Shadow: #00000066
  // Status colors
  // Success: #55D6A0
  // Warning: #F0B969
  // Error: #FF747E
  // Information: #91B7FF

  static const AppThemeColors darkColors = AppThemeColors(
    isDark: true,
    bg: Color(0xFF050609), // Deep Background: #050609
    bgSecondary: Color(0xFF0B0E14), // Secondary Background: #0B0E14
    surface: Color(0xFF10141D), // Primary Surface: #10141D
    surfaceElevated: Color(0xFF1A2230), // Elevated Surface: #1A2230
    surfaceGlass: Color(0x12FFFFFF), // Glass Overlay: #FFFFFF12
    surfaceGlassFloating: Color(0x20FFFFFF), // Strong Glass Overlay: #FFFFFF20
    surfaceGlassInput: Color(0x12FFFFFF), // Glass Overlay: #FFFFFF12
    glassBorder: Color(0xFF34435D), // Primary Border: #34435D
    glassBorderSpecular: Color(0x26477BFF), // Blue Glass Highlight: #477BFF26
    glassBorderSubtle: Color(0xFF222D40), // Subtle Border: #222D40
    textPrimary: Color(0xFFF8FAFF), // Primary Text: #F8FAFF
    textSecondary: Color(0xFFA0AABD), // Secondary Text: #A0AABD
    textTertiary: Color(0xFF68758A), // Muted Text: #68758A
    primary: Color(0xFF477BFF), // Electric Blue: #477BFF
    primaryLight: Color(0xFF91B7FF), // Ice Blue: #91B7FF
    secondary: Color(0xFF8067FF), // Violet Highlight: #8067FF
    accent: Color(0xFF263F73), // Ambient Blue: #263F73
    accentGreen: Color(0xFF55D6A0), // Success: #55D6A0
    accentRose: Color(0xFFFF747E), // Error: #FF747E
    accentAmber: Color(0xFFF0B969), // Warning: #F0B969
    glassOverlay: Color(0x12FFFFFF), // Glass Overlay: #FFFFFF12
    strongGlassOverlay: Color(0x20FFFFFF), // Strong Glass Overlay: #FFFFFF20
    blueGlassHighlight: Color(0x26477BFF), // Blue Glass Highlight: #477BFF26
    glassShadow: Color(0x66000000), // Glass Shadow: #00000066
  );

  static const AppThemeColors lightColors = AppThemeColors(
    isDark: false,
    bg: Color(0xFF050609), // Preserves uniform Luxury Cinematic Dark experience
    bgSecondary: Color(0xFF0B0E14),
    surface: Color(0xFF10141D),
    surfaceElevated: Color(0xFF1A2230),
    surfaceGlass: Color(0x12FFFFFF),
    surfaceGlassFloating: Color(0x20FFFFFF),
    surfaceGlassInput: Color(0x12FFFFFF),
    glassBorder: Color(0xFF34435D),
    glassBorderSpecular: Color(0x26477BFF),
    glassBorderSubtle: Color(0xFF222D40),
    textPrimary: Color(0xFFF8FAFF),
    textSecondary: Color(0xFFA0AABD),
    textTertiary: Color(0xFF68758A),
    primary: Color(0xFF477BFF),
    primaryLight: Color(0xFF91B7FF),
    secondary: Color(0xFF8067FF),
    accent: Color(0xFF263F73),
    accentGreen: Color(0xFF55D6A0),
    accentRose: Color(0xFFFF747E),
    accentAmber: Color(0xFFF0B969),
    glassOverlay: Color(0x12FFFFFF),
    strongGlassOverlay: Color(0x20FFFFFF),
    blueGlassHighlight: Color(0x26477BFF),
    glassShadow: Color(0x66000000),
  );

  /// Dynamic context accessor for Realtime Colors based on system theme
  static AppThemeColors colors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkColors : lightColors;
  }

  // Backward-compatible static color constants mapped to strict palette
  static const Color appleBlue = Color(0xFF477BFF); // Electric Blue: #477BFF
  static const Color primaryBlue = Color(0xFF477BFF); // Electric Blue: #477BFF
  static const Color primaryAccent = Color(0xFF477BFF);
  static const Color neonAzure = Color(0xFF91B7FF); // Ice Blue: #91B7FF
  static const Color emeraldGreen = Color(0xFF55D6A0); // Success: #55D6A0
  static const Color amberWarning = Color(0xFFF0B969); // Warning: #F0B969
  static const Color roseDanger = Color(0xFFFF747E); // Error: #FF747E
  static const Color indigoPurple = Color(0xFF8067FF); // Violet Highlight: #8067FF
  static const Color electricViolet = Color(0xFF8067FF); // Violet Highlight: #8067FF
  static const Color pureWhite = Color(0xFFF8FAFF); // Primary Text: #F8FAFF

  static const Color darkBg = Color(0xFF050609); // Deep Background: #050609
  static const Color darkBgSecondary = Color(0xFF0B0E14); // Secondary Background: #0B0E14
  static const Color darkCard = Color(0xFF10141D); // Primary Surface: #10141D
  static const Color darkCardElevated = Color(0xFF1A2230); // Elevated Surface: #1A2230
  static const Color darkCardBorder = Color(0xFF34435D); // Primary Border: #34435D
  static const Color darkTextPrimary = Color(0xFFF8FAFF); // Primary Text: #F8FAFF
  static const Color darkTextSecondary = Color(0xFFA0AABD); // Secondary Text: #A0AABD
  static const Color darkTextTertiary = Color(0xFF68758A); // Muted Text: #68758A

  // ─── Motion Primitives: Physics & Timing Curves ────────────────────
  static const Duration motionFast = Duration(milliseconds: 160);
  static const Duration motionNormal = Duration(milliseconds: 280);
  static const Duration motionSpring = Duration(milliseconds: 360);
  static const Curve motionCurve = Curves.easeOutCubic;
  static const Curve motionBounce = Curves.easeOutBack;
  static const Curve springCurve = Curves.easeOutBack;

  // ─── Liquid Motion Curves ──────────────────────────────────────────
  /// Organic spring-like elastic settle (damping: 20, stiffness: 300 feel)
  static const Curve liquidSpring = _LiquidSpringCurve();

  /// Smooth viscous deceleration — like dragging through thick fluid
  static const Curve liquidViscous = _ViscousFluidCurve();

  /// Elastic overshoot with fast damping — for playful blob interactions
  static const Curve liquidElastic = Curves.elasticOut;

  /// Slow organic ease for large-scale morphs (blob size, gradient shifts)
  static const Curve liquidMorph = Cubic(0.22, 1.0, 0.36, 1.0);

  /// Snappy spring for micro-interactions (button press, pill toggle)
  /// Strictly clamped to [0.0, 1.0] to prevent negative blur radius assertions in Shadow.lerp
  static const Curve liquidSnap = Cubic(0.2, 0.9, 0.2, 1.0);

  /// Specular Glass Edge Gradient (Simulates light catching the top-left glass bevel)
  static LinearGradient specularGlassGradient([BuildContext? context]) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x20FFFFFF), // Strong Glass Overlay: #FFFFFF20
        Color(0x12FFFFFF), // Glass Overlay: #FFFFFF12
        Colors.transparent,
      ],
      stops: [0.0, 0.45, 1.0],
    );
  }

  // ─── Liquid Gradient for ShaderMask Widgets ────────────────────────
  /// Returns animated-friendly gradient stops for use in ShaderMask widgets.
  /// [phase] is a 0→1 animation value; the stops shift to create living
  /// color movement across surfaces using strictly the approved accent palette.
  static LinearGradient liquidGradient({
    double phase = 0.0,
    BuildContext? context,
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    final c = context != null ? colors(context) : darkColors;
    final shift = phase % 1.0;
    final s0 = (0.0 + shift * 0.3).clamp(0.0, 1.0);
    final s1 = (0.35 + shift * 0.2).clamp(0.0, 1.0);
    final s2 = (0.70 + shift * 0.15).clamp(0.0, 1.0);

    return LinearGradient(
      begin: begin,
      end: end,
      colors: [
        c.primary, // Electric Blue: #477BFF
        c.secondary, // Violet Highlight: #8067FF
        c.primaryLight, // Ice Blue: #91B7FF
      ],
      stops: [s0, s1, s2],
    );
  }

  /// Translucent Frosted Glass App Bar Decoration
  static BoxDecoration appleBlurBar({
    BuildContext? context,
    Color? backgroundColor,
    bool showBottomBorder = true,
    bool showTopBorder = false,
  }) {
    final c = context != null ? colors(context) : darkColors;
    final bg = backgroundColor ?? c.bgSecondary.withOpacity(0.85);
    final borderCol = c.glassBorderSubtle; // Subtle Border: #222D40

    return BoxDecoration(
      color: bg,
      border: Border(
        bottom: showBottomBorder
            ? BorderSide(color: borderCol, width: 0.6)
            : BorderSide.none,
        top: showTopBorder
            ? BorderSide(color: borderCol, width: 0.6)
            : BorderSide.none,
      ),
    );
  }

  // ─── 3-Layer Liquid Depth Shadows ──────────────────────────────────
  /// 3D Ambient Depth & Colored Glow Shadow with Glass Shadow (#00000066)
  static List<BoxShadow> depthShadow({
    double depth = 8.0,
    Color? glowColor,
    double glowOpacity = 0.20,
    Color? shadowColor,
  }) {
    final baseShadow = shadowColor ?? const Color(0x66000000); // Glass Shadow: #00000066
    return [
      // Layer 1: Tight sharp contact shadow
      BoxShadow(
        color: baseShadow,
        blurRadius: math.max(0.0, depth * 0.5),
        spreadRadius: -1,
        offset: Offset(0, depth * 0.15),
      ),
      // Layer 2: Medium diffuse body shadow
      BoxShadow(
        color: baseShadow.withOpacity(0.40),
        blurRadius: math.max(0.0, depth * 1.8),
        offset: Offset(0, depth * 0.45),
      ),
      // Layer 3: Ambient glow shadow
      BoxShadow(
        color: baseShadow.withOpacity(0.20),
        blurRadius: math.max(0.0, depth * 3.5),
        spreadRadius: depth * 0.1,
        offset: Offset(0, depth * 0.8),
      ),
      if (glowColor != null)
        BoxShadow(
          color: glowColor.withOpacity(glowOpacity),
          blurRadius: math.max(0.0, depth * 2.5),
          offset: Offset(0, depth * 0.3),
        ),
    ];
  }

  /// 3D Pill / Capsule Decoration with Motion Primitives feedback
  static BoxDecoration pill3DDecoration({
    BuildContext? context,
    Color? backgroundColor,
    Color? borderColor,
    bool isSelected = false,
    Color? glowColor,
    double borderRadius = 20.0,
  }) {
    final c = context != null ? colors(context) : darkColors;
    final bg = backgroundColor ?? c.surfaceElevated;
    final primaryCol = c.primary;

    return BoxDecoration(
      color: isSelected ? primaryCol : bg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: isSelected
          ? Border.all(color: Colors.transparent, width: 0.6)
          : (borderColor != null
              ? Border.all(color: borderColor, width: 0.6)
              : Border.all(color: c.glassBorderSubtle, width: 0.6)), // Subtle Border: #222D40
      boxShadow: isSelected
          ? [
              BoxShadow(
                color: (glowColor ?? primaryCol).withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
              const BoxShadow(
                color: Color(0x66000000), // Glass Shadow: #00000066
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ]
          : const [
              BoxShadow(
                color: Color(0x66000000), // Glass Shadow: #00000066
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
    );
  }

  /// 3D Floating Glassmorphic Navbar Decoration
  static BoxDecoration floatingNavbarDecoration({
    BuildContext? context,
    Color? backgroundColor,
    double borderRadius = 34.0,
    Color? borderColor,
  }) {
    final c = context != null ? colors(context) : darkColors;
    final bg = backgroundColor ?? c.surfaceElevated.withOpacity(0.85);

    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: borderColor != null
          ? Border.all(color: borderColor, width: 0.75)
          : Border.all(color: c.glassBorder, width: 0.75), // Primary Border: #34435D
      boxShadow: const [
        // Layer 1: Tight contact
        BoxShadow(
          color: Color(0x66000000), // Glass Shadow: #00000066
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
        // Layer 2: Medium body shadow
        BoxShadow(
          color: Color(0x66000000), // Glass Shadow: #00000066
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
        // Layer 3: Blue Glass Highlight glow
        BoxShadow(
          color: Color(0x26477BFF), // Blue Glass Highlight: #477BFF26
          blurRadius: 20,
          offset: Offset(0, 2),
        ),
      ],
    );
  }

  /// General 3D Glassmorphic Card Decoration
  static BoxDecoration glassCardDecoration({
    BuildContext? context,
    double borderRadius = 18.0,
    Color? backgroundColor,
    Color? borderColor,
    double borderWidth = 0.6,
    Color? glowColor,
  }) {
    final c = context != null ? colors(context) : darkColors;
    final bg = backgroundColor ?? c.surface;

    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: borderColor != null
          ? Border.all(color: borderColor, width: borderWidth)
          : Border.all(color: c.glassBorderSubtle, width: borderWidth), // Subtle Border: #222D40
      boxShadow: [
        const BoxShadow(
          color: Color(0x66000000), // Glass Shadow: #00000066
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
        if (glowColor != null)
          BoxShadow(
            color: glowColor.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 2),
          ),
      ],
    );
  }

  // ─── New Liquid Decoration Helpers ─────────────────────────────────

  /// Liquid shimmer decoration — a BoxDecoration with a gradient overlay
  /// simulating liquid surface light movement.
  static BoxDecoration liquidShimmerDecoration({
    BuildContext? context,
    double borderRadius = 18.0,
    double phase = 0.0,
  }) {
    final c = context != null ? colors(context) : darkColors;

    final angle = phase * 2 * math.pi;
    final begin = Alignment(math.cos(angle), math.sin(angle));
    final end = Alignment(-math.cos(angle), -math.sin(angle));

    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      gradient: LinearGradient(
        begin: begin,
        end: end,
        colors: [
          Colors.transparent,
          c.glassOverlay, // Glass Overlay: #FFFFFF12
          c.strongGlassOverlay, // Strong Glass Overlay: #FFFFFF20
          c.glassOverlay, // Glass Overlay: #FFFFFF12
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ),
      border: Border.all(color: c.glassBorderSubtle, width: 0.5), // Subtle Border: #222D40
    );
  }

  /// Liquid pill decoration — pill-shaped containers with inner glow
  /// and soft outer radiance, evoking a liquid capsule.
  static BoxDecoration liquidPillDecoration({
    BuildContext? context,
    Color? color,
    Color? glowColor,
    double borderRadius = 100.0,
  }) {
    final c = context != null ? colors(context) : darkColors;
    final pillColor = color ?? c.surfaceElevated;
    final glow = glowColor ?? c.primary;

    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      color: pillColor,
      border: Border.all(color: c.glassBorderSubtle, width: 0.6), // Subtle Border: #222D40
      boxShadow: [
        BoxShadow(
          color: glow.withOpacity(0.12),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
        const BoxShadow(
          color: Color(0x66000000), // Glass Shadow: #00000066
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
    );
  }

  /// Liquid input decoration — for search bars with soft pulsing inner glow.
  static BoxDecoration liquidInputDecoration({
    BuildContext? context,
    double borderRadius = 14.0,
    double pulsePhase = 0.0,
    bool isFocused = false,
  }) {
    final c = context != null ? colors(context) : darkColors;

    return BoxDecoration(
      color: c.surfaceElevated, // Elevated Surface: #1A2230
      borderRadius: BorderRadius.circular(borderRadius),
      border: isFocused
          ? Border.all(
              color: c.primary, // Electric Blue: #477BFF
              width: 1.0,
            )
          : Border.all(color: c.glassBorderSubtle, width: 0.6), // Subtle Border: #222D40
      boxShadow: isFocused
          ? const [
              BoxShadow(
                color: Color(0x26477BFF), // Blue Glass Highlight: #477BFF26
                blurRadius: 10,
                offset: Offset.zero,
              ),
            ]
          : const [
              BoxShadow(
                color: Color(0x66000000), // Glass Shadow: #00000066
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
    );
  }

  /// Dark Theme (Luxury Cinematic Dark)
  static ThemeData get darkTheme {
    const c = darkColors;
    final baseTextTheme = ThemeData.dark().textTheme;
    final textTheme = GoogleFonts.interTextTheme(baseTextTheme).apply(
      bodyColor: c.textPrimary,
      displayColor: c.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: c.bg, // Deep Background: #050609
      colorScheme: ColorScheme.dark(
        primary: c.primary, // Electric Blue: #477BFF
        secondary: c.secondary, // Violet Highlight: #8067FF
        surface: c.surface, // Primary Surface: #10141D
        error: c.accentRose, // Error: #FF747E
        onPrimary: c.textPrimary,
        onSurface: c.textPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.glassBorderSubtle, width: 0.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: c.primary,
          foregroundColor: c.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: -0.2,
          ),
        ),
      ),
      dividerColor: c.glassBorderSubtle,
    );
  }

  /// Light Theme (mirrors Luxury Cinematic styling for visual consistency)
  static ThemeData get lightTheme {
    const c = lightColors;
    final baseTextTheme = ThemeData.dark().textTheme;
    final textTheme = GoogleFonts.interTextTheme(baseTextTheme).apply(
      bodyColor: c.textPrimary,
      displayColor: c.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: c.bg,
      colorScheme: ColorScheme.dark(
        primary: c.primary,
        secondary: c.secondary,
        surface: c.surface,
        error: c.accentRose,
        onPrimary: c.textPrimary,
        onSurface: c.textPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.glassBorderSubtle, width: 0.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: c.primary,
          foregroundColor: c.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: -0.2,
          ),
        ),
      ),
      dividerColor: c.glassBorderSubtle,
    );
  }
}

// ─── Custom Liquid Motion Curves ──────────────────────────────────────

/// Spring-physics-inspired curve simulating fluid resistance and settle.
/// Mimics damping: 20, stiffness: 300 spring behavior within a parametric curve.
class _LiquidSpringCurve extends Curve {
  const _LiquidSpringCurve();

  @override
  double transformInternal(double t) {
    // Critically-damped spring approximation: 1 - (1 + wt)e^(-wt)
    // w chosen so the curve settles cleanly at t=1.
    const w = 8.0; // angular frequency approximating stiffness/damping ratio
    return 1.0 - (1.0 + w * t) * math.exp(-w * t);
  }
}

/// Viscous fluid deceleration — gives the sensation of moving through
/// a thick liquid medium. Fast initial response, long slow tail.
class _ViscousFluidCurve extends Curve {
  const _ViscousFluidCurve();

  @override
  double transformInternal(double t) {
    // Based on Android's ViscousFluidInterpolator formula
    const v = 5.0;
    final x = v * t;
    return (math.exp(-x / v) * (-1.0) + 1.0) /
        (math.exp(-1.0) * (-1.0) + 1.0) *
        _viscousNormalize(t);
  }

  double _viscousNormalize(double t) {
    // Normalize so f(1) = 1 exactly
    const v = 5.0;
    return t <= 0.0
        ? 0.0
        : 1.0 - math.exp(-v * t) * (1.0 + v * t * 0.36);
  }
}
