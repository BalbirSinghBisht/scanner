import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Realtime Colors Palettes (realtimecolors.com)
/// Provides cohesive, high-contrast, accessible 5-part color tokens
/// for both Dark (Obsidian Cosmic Luxe) and Light (Pristine Pearlescent Alabaster).
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

  // Realtime Colors 5-part Brand Palette
  final Color primary;
  final Color primaryLight;
  final Color secondary;
  final Color accent;
  final Color accentGreen;
  final Color accentRose;
  final Color accentAmber;

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
  });
}

class AppTheme {
  // --- REALTIME COLORS DEFINITIONS ---
  static const AppThemeColors darkColors = AppThemeColors(
    isDark: true,
    bg: Color(0xFF08090E), // Deep Space Obsidian
    bgSecondary: Color(0xFF10131E), // Elevated Deep Base
    surface: Color(0xFF141824), // System Card Surface
    surfaceElevated: Color(0xFF1C2236), // Floating Layer
    surfaceGlass: Color(0x99121626), // 60% Frosted Obsidian Glass
    surfaceGlassFloating: Color(0xD9141828), // 85% Floating Glass
    surfaceGlassInput: Color(0x66181D2E),
    glassBorder: Color(0x2EFFFFFF), // 18% Specular Rim
    glassBorderSpecular: Color(0x4FFFFFFF), // 31% Top Bevel Glare
    glassBorderSubtle: Color(0x1AFFFFFF), // 10% Divider/Outline
    textPrimary: Color(0xFFF8FAFC), // Pure Ice White
    textSecondary: Color(0xFF94A3B8), // Cool Slate
    textTertiary: Color(0xFF64748B),
    primary: Color(0xFF3B82F6), // Electric Royal Blue
    primaryLight: Color(0xFF60A5FA),
    secondary: Color(0xFF8B5CF6), // Vivid Electric Violet
    accent: Color(0xFF06B6D4), // Luminous Neon Cyan
    accentGreen: Color(0xFF10B981), // Emerald
    accentRose: Color(0xFFF43F5E), // Rose Red
    accentAmber: Color(0xFFF59E0B), // Radiant Amber
  );

  static const AppThemeColors lightColors = AppThemeColors(
    isDark: false,
    bg: Color(0xFFF6F8FC), // Pristine Pearlescent Alabaster
    bgSecondary: Color(0xFFEDF2F9), // Elevated Crisp Base
    surface: Color(0xFFFFFFFF), // Pure White Card
    surfaceElevated: Color(0xFFF8FAFC), // Floating Layer
    surfaceGlass: Color(0xCCFFFFFF), // 80% Frosted Crystal Glass
    surfaceGlassFloating: Color(0xEBFFFFFF), // 92% Floating Crystal
    surfaceGlassInput: Color(0xE0F1F5F9),
    glassBorder: Color(0x330F172A), // 20% Subtle Slate Edge
    glassBorderSpecular: Color(0x66FFFFFF), // Specular light highlight
    glassBorderSubtle: Color(0x180F172A), // 9% Crisp outline
    textPrimary: Color(0xFF0F172A), // Deep Slate Navy
    textSecondary: Color(0xFF475569), // Balanced Medium Slate
    textTertiary: Color(0xFF94A3B8),
    primary: Color(0xFF2563EB), // Cobalt Royal Blue
    primaryLight: Color(0xFF3B82F6),
    secondary: Color(0xFF7C3AED), // Royal Violet
    accent: Color(0xFF0284C7), // Sky Azure
    accentGreen: Color(0xFF059669), // Deep Emerald
    accentRose: Color(0xFFE11D48), // Vivid Rose
    accentAmber: Color(0xFFD97706), // Amber Bronze
  );

  /// Dynamic context accessor for Realtime Colors based on system theme
  static AppThemeColors colors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkColors : lightColors;
  }

  // Backward-compatible static color constants
  static const Color appleBlue = Color(0xFF3B82F6);
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryAccent = Color(0xFF3B82F6);
  static const Color neonAzure = Color(0xFF06B6D4);
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color amberWarning = Color(0xFFF59E0B);
  static const Color roseDanger = Color(0xFFF43F5E);
  static const Color indigoPurple = Color(0xFF8B5CF6);
  static const Color electricViolet = Color(0xFFBF5AF2);
  static const Color pureWhite = Color(0xFFFFFFFF);

  static const Color darkBg = Color(0xFF08090E);
  static const Color darkBgSecondary = Color(0xFF10131E);
  static const Color darkCard = Color(0xFF141824);
  static const Color darkCardElevated = Color(0xFF1C2236);
  static const Color darkCardBorder = Color(0x2EFFFFFF);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF64748B);

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
  static const Curve liquidSnap = Cubic(0.175, 0.885, 0.32, 1.275);

  /// Specular Glass Edge Gradient (Simulates light catching the top-left glass bevel)
  static LinearGradient specularGlassGradient([BuildContext? context]) {
    final isDark = context != null
        ? (Theme.of(context).brightness == Brightness.dark)
        : true;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              const Color(0x45FFFFFF),
              const Color(0x18FFFFFF),
              const Color(0x05FFFFFF),
            ]
          : [
              const Color(0x60FFFFFF),
              const Color(0x200F172A),
              const Color(0x0A0F172A),
            ],
      stops: const [0.0, 0.45, 1.0],
    );
  }

  // ─── Liquid Gradient for ShaderMask Widgets ────────────────────────
  /// Returns animated-friendly gradient stops for use in ShaderMask widgets.
  /// [phase] is a 0→1 animation value; the stops shift to create living
  /// color movement across surfaces.
  static LinearGradient liquidGradient({
    double phase = 0.0,
    BuildContext? context,
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    final isDark = context != null
        ? (Theme.of(context).brightness == Brightness.dark)
        : true;
    // Rotate stops cyclically with phase
    final shift = phase % 1.0;
    final s0 = (0.0 + shift * 0.3).clamp(0.0, 1.0);
    final s1 = (0.25 + shift * 0.2).clamp(0.0, 1.0);
    final s2 = (0.55 + shift * 0.15).clamp(0.0, 1.0);
    final s3 = (0.85 + shift * 0.1).clamp(0.0, 1.0);

    if (isDark) {
      return LinearGradient(
        begin: begin,
        end: end,
        colors: const [
          Color(0xFF3B82F6), // Electric blue
          Color(0xFF8B5CF6), // Violet
          Color(0xFF06B6D4), // Cyan
          Color(0xFFF59E0B), // Amber glow
        ],
        stops: [s0, s1, s2, s3],
      );
    } else {
      return LinearGradient(
        begin: begin,
        end: end,
        colors: const [
          Color(0xFF2563EB), // Cobalt
          Color(0xFF7C3AED), // Royal violet
          Color(0xFF0284C7), // Sky azure
          Color(0xFFD97706), // Amber bronze
        ],
        stops: [s0, s1, s2, s3],
      );
    }
  }

  /// Translucent Frosted Glass App Bar Decoration
  static BoxDecoration appleBlurBar({
    BuildContext? context,
    Color? backgroundColor,
    bool showBottomBorder = true,
    bool showTopBorder = false,
  }) {
    final isDark = context != null
        ? (Theme.of(context).brightness == Brightness.dark)
        : true;
    final c = isDark ? darkColors : lightColors;
    final bg = backgroundColor ?? c.surfaceGlass;
    final borderCol = c.glassBorderSubtle;

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
  /// 3D Ambient Depth & Colored Glow Shadow — now 3-layer for true depth:
  /// 1) Tight sharp contact shadow  2) Medium diffuse body  3) Wide ambient glow
  static List<BoxShadow> depthShadow({
    double depth = 8.0,
    Color? glowColor,
    double glowOpacity = 0.20,
    Color? shadowColor,
  }) {
    final baseShadow = shadowColor ?? Colors.black;
    return [
      // Layer 1: Tight sharp contact shadow
      BoxShadow(
        color: baseShadow.withOpacity(0.45),
        blurRadius: depth * 0.5,
        spreadRadius: -1,
        offset: Offset(0, depth * 0.15),
      ),
      // Layer 2: Medium diffuse body shadow
      BoxShadow(
        color: baseShadow.withOpacity(0.25),
        blurRadius: depth * 1.8,
        offset: Offset(0, depth * 0.45),
      ),
      // Layer 3: Wide ambient glow
      BoxShadow(
        color: baseShadow.withOpacity(0.10),
        blurRadius: depth * 3.5,
        spreadRadius: depth * 0.2,
        offset: Offset(0, depth * 0.8),
      ),
      if (glowColor != null)
        BoxShadow(
          color: glowColor.withOpacity(glowOpacity),
          blurRadius: depth * 2.5,
          offset: Offset(0, depth * 0.3),
        ),
    ];
  }

  // ─── Gradient Border Helper ────────────────────────────────────────
  /// Creates a refined liquid border that simulates light catching curved glass surfaces.
  /// Uses a uniform specular tint to ensure complete compatibility with Flutter's borderRadius.
  static Border _liquidGradientBorder(AppThemeColors c, {double width = 0.7}) {
    return Border.all(
      color: c.isDark ? const Color(0x35FFFFFF) : const Color(0x300F172A),
      width: width,
    );
  }

  /// 3D Pill / Capsule Decoration with Motion Primitives feedback
  /// Now with gradient borders simulating light on curved liquid surfaces.
  static BoxDecoration pill3DDecoration({
    BuildContext? context,
    Color? backgroundColor,
    Color? borderColor,
    bool isSelected = false,
    Color? glowColor,
    double borderRadius = 20.0,
  }) {
    final isDark = context != null
        ? (Theme.of(context).brightness == Brightness.dark)
        : true;
    final c = isDark ? darkColors : lightColors;
    final bg = backgroundColor ?? c.surfaceGlass;
    final primaryCol = c.primary;

    return BoxDecoration(
      color: isSelected ? primaryCol : bg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: isSelected
          ? Border.all(color: Colors.transparent, width: 0.6)
          : (borderColor != null
              ? Border.all(color: borderColor, width: 0.6)
              : _liquidGradientBorder(c)),
      boxShadow: isSelected
          ? [
              // Layer 1: Tight glow
              BoxShadow(
                color: (glowColor ?? primaryCol).withOpacity(0.50),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
              // Layer 2: Medium radiance
              BoxShadow(
                color: (glowColor ?? primaryCol).withOpacity(0.30),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
              // Layer 3: Wide ambient
              BoxShadow(
                color: (glowColor ?? primaryCol).withOpacity(0.12),
                blurRadius: 28,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withOpacity(c.isDark ? 0.30 : 0.06),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(c.isDark ? 0.15 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(c.isDark ? 0.06 : 0.02),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
            ],
    );
  }

  /// 3D Floating Glassmorphic Navbar Decoration
  /// Now with gradient borders and 3-layer depth shadows.
  static BoxDecoration floatingNavbarDecoration({
    BuildContext? context,
    Color? backgroundColor,
    double borderRadius = 34.0,
    Color? borderColor,
  }) {
    final isDark = context != null
        ? (Theme.of(context).brightness == Brightness.dark)
        : true;
    final c = isDark ? darkColors : lightColors;
    final bg = backgroundColor ?? c.surfaceGlassFloating;

    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: borderColor != null
          ? Border.all(color: borderColor, width: 0.75)
          : _liquidGradientBorder(c, width: 0.75),
      boxShadow: [
        // Layer 1: Tight contact
        BoxShadow(
          color: Colors.black.withOpacity(c.isDark ? 0.40 : 0.08),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
        // Layer 2: Medium body shadow
        BoxShadow(
          color: Colors.black.withOpacity(c.isDark ? 0.30 : 0.10),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        // Layer 3: Wide ambient glow
        BoxShadow(
          color: Colors.black.withOpacity(c.isDark ? 0.15 : 0.05),
          blurRadius: 40,
          spreadRadius: 4,
          offset: const Offset(0, 14),
        ),
        // Brand color glow
        BoxShadow(
          color: c.primary.withOpacity(c.isDark ? 0.10 : 0.06),
          blurRadius: 24,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// General 3D Glassmorphic Card Decoration
  /// Now with gradient borders and 3-layer depth shadows.
  static BoxDecoration glassCardDecoration({
    BuildContext? context,
    double borderRadius = 18.0,
    Color? backgroundColor,
    Color? borderColor,
    double borderWidth = 0.6,
    Color? glowColor,
  }) {
    final isDark = context != null
        ? (Theme.of(context).brightness == Brightness.dark)
        : true;
    final c = isDark ? darkColors : lightColors;
    final bg = backgroundColor ?? c.surfaceGlass;

    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: borderColor != null
          ? Border.all(color: borderColor, width: borderWidth)
          : _liquidGradientBorder(c, width: borderWidth),
      boxShadow: [
        // Layer 1: Tight sharp contact shadow
        BoxShadow(
          color: Colors.black.withOpacity(c.isDark ? 0.40 : 0.06),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
        // Layer 2: Medium diffuse body
        BoxShadow(
          color: Colors.black.withOpacity(c.isDark ? 0.25 : 0.06),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
        // Layer 3: Wide ambient glow
        BoxShadow(
          color: Colors.black.withOpacity(c.isDark ? 0.10 : 0.03),
          blurRadius: 32,
          spreadRadius: 2,
          offset: const Offset(0, 10),
        ),
        if (glowColor != null)
          BoxShadow(
            color: glowColor.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 3),
          ),
      ],
    );
  }

  // ─── New Liquid Decoration Helpers ─────────────────────────────────

  /// Liquid shimmer decoration — a BoxDecoration with a gradient overlay
  /// simulating liquid surface light movement. Use [phase] (0→1) from an
  /// AnimationController to animate the shimmer across the surface.
  static BoxDecoration liquidShimmerDecoration({
    BuildContext? context,
    double borderRadius = 18.0,
    double phase = 0.0,
  }) {
    final isDark = context != null
        ? (Theme.of(context).brightness == Brightness.dark)
        : true;
    final c = isDark ? darkColors : lightColors;

    // Shimmer sweep angle based on animation phase
    final angle = phase * 2 * math.pi;
    final begin = Alignment(math.cos(angle), math.sin(angle));
    final end = Alignment(-math.cos(angle), -math.sin(angle));

    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      gradient: LinearGradient(
        begin: begin,
        end: end,
        colors: isDark
            ? [
                const Color(0x00FFFFFF),
                const Color(0x0AFFFFFF),
                const Color(0x18FFFFFF),
                const Color(0x0AFFFFFF),
                const Color(0x00FFFFFF),
              ]
            : [
                const Color(0x00FFFFFF),
                const Color(0x30FFFFFF),
                const Color(0x50FFFFFF),
                const Color(0x30FFFFFF),
                const Color(0x00FFFFFF),
              ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ),
      border: _liquidGradientBorder(c, width: 0.5),
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
    final isDark = context != null
        ? (Theme.of(context).brightness == Brightness.dark)
        : true;
    final c = isDark ? darkColors : lightColors;
    final pillColor = color ?? c.surfaceGlass;
    final glow = glowColor ?? c.primary;

    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      color: pillColor,
      border: _liquidGradientBorder(c, width: 0.6),
      // Inner glow simulated via gradient + boxShadow
      boxShadow: [
        // Inner glow (inset simulation via tight shadow)
        BoxShadow(
          color: glow.withOpacity(isDark ? 0.08 : 0.05),
          blurRadius: 10,
          spreadRadius: -2,
          offset: Offset.zero,
        ),
        // Outer soft radiance — Layer 1
        BoxShadow(
          color: glow.withOpacity(isDark ? 0.12 : 0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
        // Outer radiance — Layer 2
        BoxShadow(
          color: glow.withOpacity(isDark ? 0.06 : 0.04),
          blurRadius: 22,
          spreadRadius: 1,
          offset: const Offset(0, 4),
        ),
        // Wide ambient — Layer 3
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.10 : 0.03),
          blurRadius: 30,
          spreadRadius: 2,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  /// Liquid input decoration — for search bars with soft pulsing inner glow.
  /// Pass [pulsePhase] (0→1) from an AnimationController for the living pulse.
  static BoxDecoration liquidInputDecoration({
    BuildContext? context,
    double borderRadius = 14.0,
    double pulsePhase = 0.0,
    bool isFocused = false,
  }) {
    final isDark = context != null
        ? (Theme.of(context).brightness == Brightness.dark)
        : true;
    final c = isDark ? darkColors : lightColors;
    final pulseIntensity = 0.5 + 0.5 * math.sin(pulsePhase * 2 * math.pi);

    final baseGlow = isFocused ? c.primary : c.accent;
    final glowOpacity = isDark
        ? (isFocused ? 0.15 : 0.04) + 0.04 * pulseIntensity
        : (isFocused ? 0.10 : 0.02) + 0.03 * pulseIntensity;

    return BoxDecoration(
      color: c.surfaceGlassInput,
      borderRadius: BorderRadius.circular(borderRadius),
      border: isFocused
          ? Border.all(
              color: baseGlow.withOpacity(isDark ? 0.5 : 0.4),
              width: 1.0,
            )
          : _liquidGradientBorder(c, width: 0.5),
      boxShadow: [
        // Pulsing inner glow
        BoxShadow(
          color: baseGlow.withOpacity(glowOpacity),
          blurRadius: 12 + 6 * pulseIntensity,
          spreadRadius: -1,
          offset: Offset.zero,
        ),
        // Subtle ambient
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.12 : 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Dark Theme (Realtime Colors Obsidian)
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
      scaffoldBackgroundColor: c.bg,
      colorScheme: ColorScheme.dark(
        primary: c.primary,
        secondary: c.secondary,
        surface: c.surface,
        error: c.accentRose,
        onPrimary: Colors.white,
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
          foregroundColor: Colors.white,
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

  /// Light Theme (Realtime Colors Pristine Pearlescent Alabaster)
  static ThemeData get lightTheme {
    const c = lightColors;
    final baseTextTheme = ThemeData.light().textTheme;
    final textTheme = GoogleFonts.interTextTheme(baseTextTheme).apply(
      bodyColor: c.textPrimary,
      displayColor: c.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: c.bg,
      colorScheme: ColorScheme.light(
        primary: c.primary,
        secondary: c.secondary,
        surface: c.surface,
        error: c.accentRose,
        onPrimary: Colors.white,
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
          foregroundColor: Colors.white,
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
