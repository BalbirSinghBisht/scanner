import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  static const Color pureWhite = Color(0xFFFFFFFF);

  // Deep Obsidian 3D Palette (Flagship luxury OLED)
  static const Color darkBg = Color(0xFF060911);
  static const Color darkBgSecondary = Color(0xFF0B111E);
  static const Color darkCard = Color(0xFF111A2E);
  static const Color darkCardElevated = Color(0xFF18243E);
  static const Color darkCardBorder = Color(0xFF20304E);
  static const Color darkCardBorderLight = Color(0xFF354B75);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF64748B);

  /// Premium Holographic/Specular Gradient for titles & highlights
  static const LinearGradient holographicGradient = LinearGradient(
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFD6EEFF),
      primaryAccent,
    ],
    stops: [0.0, 0.55, 1.0],
  );

  /// 3D Multi-tiered Depth Shadow:
  /// Combines top specular rim highlight, deep ambient drop shadow,
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
        color: Colors.white.withOpacity(0.09),
        blurRadius: 1.5,
        offset: const Offset(-0.8, -0.8),
      ),
      // Sharp contact shadow
      BoxShadow(
        color: shadowColor.withOpacity(0.48),
        blurRadius: depth * 0.8,
        offset: Offset(0, depth * 0.45),
      ),
      // Deep ambient diffuse drop shadow
      BoxShadow(
        color: shadowColor.withOpacity(0.38),
        blurRadius: depth * 2.4,
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

  /// 3D Floating Pill / Capsule Decoration
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

  /// Frosted Glass Capsule Decoration (VisionOS / Dynamic Island style)
  static BoxDecoration glassCapsuleDecoration({
    Color backgroundColor = const Color(0xCC0D1527),
    Color? borderColor,
    double borderRadius = 32.0,
    double depth = 14.0,
    Color? glowColor,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? Colors.white.withOpacity(0.14),
        width: 1.0,
      ),
      boxShadow: depthShadow(
        depth: depth,
        glowColor: glowColor,
        glowOpacity: 0.16,
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = ThemeData.dark().textTheme;
    final textTheme = GoogleFonts.outfitTextTheme(baseTextTheme).apply(
      bodyColor: darkTextPrimary,
      displayColor: darkTextPrimary,
    );

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
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          color: darkTextPrimary,
          fontSize: 21,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        iconTheme: const IconThemeData(color: darkTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
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
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryAccent,
          side: const BorderSide(color: primaryAccent, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.2,
          ),
        ),
      ),
      dividerColor: darkCardBorder,
    );
  }
}
