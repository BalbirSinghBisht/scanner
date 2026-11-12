import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Apple Photos Design System Color Tokens
/// Authentic iOS human interface guidelines palette for Photos
class AppThemeColors {
  final bool isDark;

  // Background & Canvas
  final Color bg;
  final Color bgSecondary;

  // Surfaces & Glass Materials
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceGlass;
  final Color surfaceGlassFloating;
  final Color surfaceGlassInput;

  // Glass Specular Borders (0.5px hairline separators)
  final Color glassBorder;
  final Color glassBorderSpecular;
  final Color glassBorderSubtle;

  // Apple High-contrast Typography
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  // Apple System Brand & Semantic Palette
  final Color primary; // Apple System Blue: #007AFF
  final Color primaryLight; // Light Blue / Sky: #5AC8FA
  final Color secondary; // Apple Indigo / Purple: #5856D6
  final Color accent; // Apple Accent
  final Color accentGreen; // Apple System Green: #34C759
  final Color accentRose; // Apple System Pink/Red: #FF2D55
  final Color accentAmber; // Apple System Orange: #FF9500

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
  // ─── APPLE PHOTOS DESIGN SYSTEM PALETTE ─────────────────────────────
  // True Apple iOS System Colors:
  // System Blue:   #007AFF
  // System Teal:   #5AC8FA
  // System Indigo: #5856D6
  // System Green:  #34C759
  // System Red:    #FF3B30
  // System Pink:   #FF2D55
  // System Orange: #FF9500
  // System Yellow: #FFCC00 (Apple Photos edit mode accent)

  static const AppThemeColors darkColors = AppThemeColors(
    isDark: true,
    bg: Color(0xFF000000), // Apple OLED True Black for Photos
    bgSecondary: Color(0xFF121214), // Dark iOS System Background
    surface: Color(0xFF1C1C1E), // Apple Dark System Gray 6
    surfaceElevated: Color(0xFF2C2C2E), // Apple Dark System Gray 5
    surfaceGlass: Color(0xB31C1C1E), // 70% opacity frosted glass
    surfaceGlassFloating: Color(0xCC242426), // 80% opacity floating glass
    surfaceGlassInput: Color(0xFF1C1C1E),
    glassBorder: Color(0x2EFFFFFF), // 0.5px subtle separator
    glassBorderSpecular: Color(0x40007AFF), // Subtle Apple Blue sheen
    glassBorderSubtle: Color(0x1FFFFFFF), // Hairline separator
    textPrimary: Color(0xFFFFFFFF), // Pure White
    textSecondary: Color(0xFF8E8E93), // Apple System Gray
    textTertiary: Color(0xFF636366), // Apple System Gray 3
    primary: Color(0xFF007AFF), // Apple System Blue
    primaryLight: Color(0xFF5AC8FA), // Apple System Teal
    secondary: Color(0xFF5856D6), // Apple System Indigo
    accent: Color(0xFF007AFF), // Apple System Blue
    accentGreen: Color(0xFF34C759), // Apple System Green
    accentRose: Color(0xFFFF2D55), // Apple System Pink / Red
    accentAmber: Color(0xFFFF9500), // Apple System Orange
    glassOverlay: Color(0x14FFFFFF),
    strongGlassOverlay: Color(0x24FFFFFF),
    blueGlassHighlight: Color(0x26007AFF),
    glassShadow: Color(0x4D000000),
  );

  static const AppThemeColors lightColors = AppThemeColors(
    isDark: false,
    bg: Color(0xFFFFFFFF), // Apple Pristine Pure White
    bgSecondary: Color(0xFFF2F2F7), // Apple iOS Grouped System Background
    surface: Color(0xFFFFFFFF), // Crisp White Surface
    surfaceElevated: Color(0xFFF2F2F7), // Apple System Gray 6
    surfaceGlass: Color(0xCCFFFFFF), // 80% frosted white glass
    surfaceGlassFloating: Color(0xE6FFFFFF), // 90% floating white glass
    surfaceGlassInput: Color(0xFFE5E5EA), // Apple System Gray 5
    glassBorder: Color(0x24000000), // 0.5px subtle separator
    glassBorderSpecular: Color(0x26007AFF),
    glassBorderSubtle: Color(0x14000000), // Hairline separator
    textPrimary: Color(0xFF000000), // True Apple Black
    textSecondary: Color(0xFF8E8E93), // Apple System Gray
    textTertiary: Color(0xFFC7C7CC), // Apple System Gray 4
    primary: Color(0xFF007AFF), // Apple System Blue
    primaryLight: Color(0xFF5AC8FA), // Apple System Teal
    secondary: Color(0xFF5856D6), // Apple System Indigo
    accent: Color(0xFF007AFF), // Apple System Blue
    accentGreen: Color(0xFF34C759), // Apple System Green
    accentRose: Color(0xFFFF2D55), // Apple System Pink / Red
    accentAmber: Color(0xFFFF9500), // Apple System Orange
    glassOverlay: Color(0x0A000000),
    strongGlassOverlay: Color(0x14000000),
    blueGlassHighlight: Color(0x1F007AFF),
    glassShadow: Color(0x14000000),
  );

  /// Dynamic context accessor for Realtime Colors based on system theme
  static AppThemeColors colors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkColors : lightColors;
  }

  // Backward-compatible static color constants mapped to Apple system palette
  static const Color appleBlue = Color(0xFF007AFF);
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color primaryAccent = Color(0xFF007AFF);
  static const Color neonAzure = Color(0xFF5AC8FA);
  static const Color emeraldGreen = Color(0xFF34C759);
  static const Color amberWarning = Color(0xFFFF9500);
  static const Color roseDanger = Color(0xFFFF2D55);
  static const Color indigoPurple = Color(0xFF5856D6);
  static const Color electricViolet = Color(0xFF5856D6);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color appleYellow = Color(0xFFFFCC00); // Apple Photos Edit accent

  static const Color darkBg = Color(0xFF000000);
  static const Color darkBgSecondary = Color(0xFF121214);
  static const Color darkCard = Color(0xFF1C1C1E);
  static const Color darkCardElevated = Color(0xFF2C2C2E);
  static const Color darkCardBorder = Color(0x2EFFFFFF);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF8E8E93);
  static const Color darkTextTertiary = Color(0xFF636366);

  // ─── Apple Physics & Motion Primitives ──────────────────────────────
  static const Duration motionFast = Duration(milliseconds: 160);
  static const Duration motionNormal = Duration(milliseconds: 280);
  static const Duration motionSpring = Duration(milliseconds: 360);
  static const Curve motionCurve = Curves.easeOutCubic;
  static const Curve motionBounce = Curves.easeOutBack;
  static const Curve springCurve = Curves.easeOutBack;

  // ─── Liquid Motion Curves ──────────────────────────────────────────
  static const Curve liquidSpring = _LiquidSpringCurve();
  static const Curve liquidViscous = _ViscousFluidCurve();
  static const Curve liquidElastic = Curves.elasticOut;
  static const Curve liquidMorph = Cubic(0.22, 1.0, 0.36, 1.0);
  static const Curve liquidSnap = Cubic(0.2, 0.9, 0.2, 1.0);

  /// Specular Glass Edge Gradient (Simulates light catching the glass bevel)
  static LinearGradient specularGlassGradient([BuildContext? context]) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x24FFFFFF),
        Color(0x0FFFFFFF),
        Colors.transparent,
      ],
      stops: [0.0, 0.45, 1.0],
    );
  }

  /// Apple Accent Gradient
  static LinearGradient liquidGradient({
    double phase = 0.0,
    BuildContext? context,
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    final c = context != null ? colors(context) : darkColors;
    final shift = phase % 1.0;
    final s0 = (0.0 + shift * 0.3).clamp(0.0, 1.0);
    final s1 = (0.45 + shift * 0.2).clamp(0.0, 1.0);
    final s2 = (0.80 + shift * 0.15).clamp(0.0, 1.0);

    return LinearGradient(
      begin: begin,
      end: end,
      colors: [
        c.primary,
        c.primaryLight,
        c.secondary,
      ],
      stops: [s0, s1, s2],
    );
  }

  /// Translucent Frosted Glass App Bar Decoration (Apple Cupertino style)
  static BoxDecoration appleBlurBar({
    BuildContext? context,
    Color? backgroundColor,
    bool showBottomBorder = true,
    bool showTopBorder = false,
  }) {
    final c = context != null ? colors(context) : darkColors;
    final bg = backgroundColor ??
        (c.isDark
            ? const Color(0xCC000000)
            : const Color(0xCCFFFFFF));
    final borderCol = c.glassBorderSubtle;

    return BoxDecoration(
      color: bg,
      border: Border(
        bottom: showBottomBorder
            ? BorderSide(color: borderCol, width: 0.5)
            : BorderSide.none,
        top: showTopBorder
            ? BorderSide(color: borderCol, width: 0.5)
            : BorderSide.none,
      ),
    );
  }

  // ─── Apple Depth & Soft Diffuse Shadows ─────────────────────────────
  static List<BoxShadow> depthShadow({
    double depth = 8.0,
    Color? glowColor,
    double glowOpacity = 0.15,
    Color? shadowColor,
  }) {
    final baseShadow = shadowColor ?? const Color(0x33000000);
    return [
      BoxShadow(
        color: baseShadow.withOpacity(0.12),
        blurRadius: math.max(0.0, depth * 0.8),
        offset: Offset(0, depth * 0.2),
      ),
      BoxShadow(
        color: baseShadow.withOpacity(0.08),
        blurRadius: math.max(0.0, depth * 2.0),
        offset: Offset(0, depth * 0.5),
      ),
      if (glowColor != null)
        BoxShadow(
          color: glowColor.withOpacity(glowOpacity),
          blurRadius: math.max(0.0, depth * 1.8),
          offset: Offset(0, depth * 0.3),
        ),
    ];
  }

  /// Apple Capsule / Pill Decoration
  static BoxDecoration pill3DDecoration({
    BuildContext? context,
    Color? backgroundColor,
    Color? borderColor,
    bool isSelected = false,
    Color? glowColor,
    double borderRadius = 20.0,
  }) {
    final c = context != null ? colors(context) : darkColors;
    final bg = backgroundColor ??
        (c.isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA));
    final primaryCol = c.primary;

    return BoxDecoration(
      color: isSelected ? primaryCol : bg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: isSelected
          ? Border.all(color: Colors.transparent, width: 0.5)
          : (borderColor != null
              ? Border.all(color: borderColor, width: 0.5)
              : Border.all(color: c.glassBorderSubtle, width: 0.5)),
      boxShadow: isSelected
          ? [
              BoxShadow(
                color: (glowColor ?? primaryCol).withOpacity(0.30),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
          : null,
    );
  }

  /// Apple Floating Frosted Glass Navbar Decoration
  static BoxDecoration floatingNavbarDecoration({
    BuildContext? context,
    Color? backgroundColor,
    double borderRadius = 34.0,
    Color? borderColor,
  }) {
    final c = context != null ? colors(context) : darkColors;
    final bg = backgroundColor ??
        (c.isDark
            ? const Color(0xD91E1E22)
            : const Color(0xE6FFFFFF));

    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: borderColor != null
          ? Border.all(color: borderColor, width: 0.5)
          : Border.all(color: c.glassBorderSubtle, width: 0.5),
      boxShadow: [
        BoxShadow(
          color: c.isDark ? const Color(0x59000000) : const Color(0x1A000000),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  /// Apple Photos Card Decoration
  static BoxDecoration glassCardDecoration({
    BuildContext? context,
    double borderRadius = 20.0,
    Color? backgroundColor,
    Color? borderColor,
    double borderWidth = 0.5,
    Color? glowColor,
  }) {
    final c = context != null ? colors(context) : darkColors;
    final bg = backgroundColor ?? c.surface;

    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: borderColor != null
          ? Border.all(color: borderColor, width: borderWidth)
          : Border.all(color: c.glassBorderSubtle, width: borderWidth),
      boxShadow: [
        BoxShadow(
          color: c.isDark ? const Color(0x40000000) : const Color(0x0D000000),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  /// Shimmer decoration
  static BoxDecoration liquidShimmerDecoration({
    BuildContext? context,
    double borderRadius = 20.0,
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
          c.glassOverlay,
          c.strongGlassOverlay,
          c.glassOverlay,
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ),
      border: Border.all(color: c.glassBorderSubtle, width: 0.5),
    );
  }

  /// Apple Pill Decoration
  static BoxDecoration liquidPillDecoration({
    BuildContext? context,
    Color? color,
    Color? glowColor,
    double borderRadius = 100.0,
  }) {
    final c = context != null ? colors(context) : darkColors;
    final pillColor = color ?? c.surfaceElevated;

    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      color: pillColor,
      border: Border.all(color: c.glassBorderSubtle, width: 0.5),
      boxShadow: [
        BoxShadow(
          color: c.isDark ? const Color(0x33000000) : const Color(0x0D000000),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Apple Search Bar Input Decoration
  static BoxDecoration liquidInputDecoration({
    BuildContext? context,
    double borderRadius = 16.0,
    double pulsePhase = 0.0,
    bool isFocused = false,
  }) {
    final c = context != null ? colors(context) : darkColors;
    final fill = c.isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA);

    return BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(borderRadius),
      border: isFocused
          ? Border.all(color: c.primary, width: 1.0)
          : Border.all(color: Colors.transparent, width: 0.5),
    );
  }

  /// Apple Photos Dark Theme
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
      iconTheme: IconThemeData(
        color: c.textPrimary,
        size: 21,
        weight: 300,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: c.primary, size: 20, weight: 300),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF000000),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Color(0xFF000000),
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: Color(0xFF000000),
          systemNavigationBarContrastEnforced: false,
          systemStatusBarContrastEnforced: false,
        ),
        titleTextStyle: TextStyle(
          color: c.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.glassBorderSubtle, width: 0.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: c.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
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

  /// Apple Photos Light Theme
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
      iconTheme: IconThemeData(
        color: c.textPrimary,
        size: 21,
        weight: 300,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: c.primary, size: 20, weight: 300),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFFFFFFFF),
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Color(0xFFFFFFFF),
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarDividerColor: Color(0xFFFFFFFF),
          systemNavigationBarContrastEnforced: false,
          systemStatusBarContrastEnforced: false,
        ),
        titleTextStyle: TextStyle(
          color: c.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.glassBorderSubtle, width: 0.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: c.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
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
class _LiquidSpringCurve extends Curve {
  const _LiquidSpringCurve();

  @override
  double transformInternal(double t) {
    const w = 8.0;
    return 1.0 - (1.0 + w * t) * math.exp(-w * t);
  }
}

class _ViscousFluidCurve extends Curve {
  const _ViscousFluidCurve();

  @override
  double transformInternal(double t) {
    const v = 5.0;
    final x = v * t;
    return (math.exp(-x / v) * (-1.0) + 1.0) /
        (math.exp(-1.0) * (-1.0) + 1.0) *
        _viscousNormalize(t);
  }

  double _viscousNormalize(double t) {
    const v = 5.0;
    return t <= 0.0
        ? 0.0
        : 1.0 - math.exp(-v * t) * (1.0 + v * t * 0.36);
  }
}
