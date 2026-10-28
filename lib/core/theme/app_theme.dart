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

  // Motion Primitives Physics & Timing Curves
  static const Duration motionFast = Duration(milliseconds: 160);
  static const Duration motionNormal = Duration(milliseconds: 280);
  static const Duration motionSpring = Duration(milliseconds: 360);
  static const Curve motionCurve = Curves.easeOutCubic;
  static const Curve motionBounce = Curves.easeOutBack;
  static const Curve springCurve = Curves.easeOutBack;

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

  /// 3D Ambient Depth & Colored Glow Shadow
  static List<BoxShadow> depthShadow({
    double depth = 8.0,
    Color? glowColor,
    double glowOpacity = 0.20,
    Color? shadowColor,
  }) {
    final baseShadow = shadowColor ?? Colors.black;
    return [
      BoxShadow(
        color: baseShadow.withOpacity(0.35),
        blurRadius: depth * 1.8,
        offset: Offset(0, depth * 0.45),
      ),
      if (glowColor != null)
        BoxShadow(
          color: glowColor.withOpacity(glowOpacity),
          blurRadius: depth * 2.2,
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
    final isDark = context != null
        ? (Theme.of(context).brightness == Brightness.dark)
        : true;
    final c = isDark ? darkColors : lightColors;
    final bg = backgroundColor ?? c.surfaceGlass;
    final primaryCol = c.primary;

    return BoxDecoration(
      color: isSelected ? primaryCol : bg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isSelected
            ? Colors.transparent
            : (borderColor ?? c.glassBorder),
        width: 0.6,
      ),
      boxShadow: isSelected
          ? [
              BoxShadow(
                color: (glowColor ?? primaryCol).withOpacity(0.38),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withOpacity(c.isDark ? 0.20 : 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
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
    final isDark = context != null
        ? (Theme.of(context).brightness == Brightness.dark)
        : true;
    final c = isDark ? darkColors : lightColors;
    final bg = backgroundColor ?? c.surfaceGlassFloating;

    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? c.glassBorder,
        width: 0.75,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(c.isDark ? 0.45 : 0.12),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: c.primary.withOpacity(c.isDark ? 0.12 : 0.08),
          blurRadius: 20,
          offset: const Offset(0, 4),
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
    final isDark = context != null
        ? (Theme.of(context).brightness == Brightness.dark)
        : true;
    final c = isDark ? darkColors : lightColors;
    final bg = backgroundColor ?? c.surfaceGlass;

    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? c.glassBorder,
        width: borderWidth,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(c.isDark ? 0.35 : 0.08),
          blurRadius: 16,
          offset: const Offset(0, 5),
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
