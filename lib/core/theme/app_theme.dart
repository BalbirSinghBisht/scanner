import 'package:flutter/material.dart';

class AppTheme {
  // Vibrant holographic accents
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryAccent = Color(0xFF00E5FF); // Electric Cyan
  static const Color neonAzure = Color(0xFF38BDF8);
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color amberWarning = Color(0xFFF59E0B);
  static const Color roseDanger = Color(0xFFF43F5E);
  static const Color indigoPurple = Color(0xFF6366F1);
  static const Color electricViolet = Color(0xFF8B5CF6);

  // Deep Obsidian 3D Palette
  static const Color darkBg = Color(0xFF070B14);
  static const Color darkBgSecondary = Color(0xFF0D1527);
  static const Color darkCard = Color(0xFF131D31);
  static const Color darkCardElevated = Color(0xFF1A2744);
  static const Color darkCardBorder = Color(0xFF243656);
  static const Color darkCardBorderLight = Color(0xFF364E78);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  /// 3D Multi-tiered Depth Shadow:
  /// Combines top-left specular rim reflection, deep ambient drop shadow,
  /// directional contact shadow, and optional color glow.
  static List<BoxShadow> depthShadow({
    double depth = 8.0,
    Color? glowColor,
    double glowOpacity = 0.25,
    Color shadowColor = Colors.black,
  }) {
    return [
      // Top-left specular rim reflection
      BoxShadow(
        color: Colors.white.withOpacity(0.08),
        blurRadius: 1.5,
        offset: const Offset(-0.8, -0.8),
      ),
      // Sharp contact shadow
      BoxShadow(
        color: shadowColor.withOpacity(0.45),
        blurRadius: depth * 0.8,
        offset: Offset(0, depth * 0.45),
      ),
      // Deep ambient diffuse drop shadow
      BoxShadow(
        color: shadowColor.withOpacity(0.35),
        blurRadius: depth * 2.2,
        offset: Offset(0, depth * 1.2),
      ),
      // Optional volumetric color glow
      if (glowColor != null)
        BoxShadow(
          color: glowColor.withOpacity(glowOpacity),
          blurRadius: depth * 2.5,
          spreadRadius: -2,
          offset: Offset(0, depth * 0.6),
        ),
    ];
  }

  /// 3D Floating Pill Decoration with specular top highlight and soft bottom depth
  static BoxDecoration pill3DDecoration({
    Color backgroundColor = darkCard,
    Color? borderColor,
    bool isSelected = false,
    Color? glowColor,
    double borderRadius = 24.0,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isSelected
            ? (borderColor ?? primaryAccent)
            : (borderColor ?? darkCardBorder),
        width: isSelected ? 1.5 : 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.white.withOpacity(0.06),
          blurRadius: 1,
          offset: const Offset(-0.5, -0.5),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.35),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
        if (isSelected && glowColor != null)
          BoxShadow(
            color: glowColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
      ],
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: primaryAccent,
        secondary: emeraldGreen,
        surface: darkCard,
        error: roseDanger,
        onPrimary: Colors.black,
        onSurface: darkTextPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: darkTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkCardBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 4,
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryAccent,
          side: const BorderSide(color: primaryAccent, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      dividerColor: darkCardBorder,
    );
  }
}
