import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Apple Human Interface Guidelines (HIG) Photos Theme
class AppTheme {
  // Apple System iOS Colors
  static const Color appleBlue = Color(0xFF0A84FF); // iOS System Blue (Dark)
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color primaryAccent = Color(0xFF0A84FF); // Apple Tint
  static const Color neonAzure = Color(0xFF64D2FF); // iOS Cyan
  static const Color emeraldGreen = Color(0xFF30D158); // iOS System Green
  static const Color amberWarning = Color(0xFFFF9F0A); // iOS System Orange
  static const Color roseDanger = Color(0xFFFF453A); // iOS System Red
  static const Color indigoPurple = Color(0xFF5E5CE6); // iOS System Indigo
  static const Color electricViolet = Color(0xFFBF5AF2); // iOS System Purple
  static const Color pureWhite = Color(0xFFFFFFFF);

  // Apple OLED Photos Dark Palette
  static const Color darkBg = Color(0xFF000000); // Pure Apple OLED Black
  static const Color darkBgSecondary = Color(0xFF121214); // Apple elevated base
  static const Color darkCard = Color(0xFF1C1C1E); // Apple System Gray 6
  static const Color darkCardElevated = Color(0xFF2C2C2E); // Apple System Gray 5
  static const Color darkCardBorder = Color(0xFF38383A);
  static const Color darkCardBorderLight = Color(0xFF48484A);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF8E8E93); // Apple System Gray
  static const Color darkTextTertiary = Color(0xFF636366);

  // Realtime Colors & Glassmorphism Surfaces
  static const Color glassSurface = Color(0x99161A26);
  static const Color glassSurfaceDark = Color(0xC210131E);
  static const Color glassSurfaceFloating = Color(0xD1141724);
  static const Color glassSurfaceLight = Color(0x4D2A3044);
  static const Color glassBorderColor = Color(0x2EFFFFFF); // 18% crisp specular edge
  static const Color glassBorderLight = Color(0x47FFFFFF); // 28% top highlight
  static const Color glassBorderUltraThin = Color(0x1FFFFFFF); // 12% subtle border

  // Motion Primitives Spring & Timing Curves
  static const Duration motionFast = Duration(milliseconds: 160);
  static const Duration motionNormal = Duration(milliseconds: 260);
  static const Duration motionSpring = Duration(milliseconds: 320);
  static const Curve motionCurve = Curves.easeOutCubic;
  static const Curve motionBounce = Curves.easeOutBack;

  /// Clean Apple Header Gradient (Subtle white to light mist)
  static const LinearGradient holographicGradient = LinearGradient(
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF2F2F7),
      Color(0xFFE5E5EA),
    ],
    stops: [0.0, 0.7, 1.0],
  );

  /// Specular Glass Edge Gradient (Simulates light catching the glass bevel)
  static const LinearGradient specularGlassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x40FFFFFF),
      Color(0x1AFFFFFF),
      Color(0x08FFFFFF),
    ],
    stops: [0.0, 0.4, 1.0],
  );

  /// Apple Cupertino Translucent Blur Bar Decoration
  static BoxDecoration appleBlurBar({
    Color backgroundColor = const Color(0xB8121520),
    bool showBottomBorder = true,
    bool showTopBorder = false,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      border: Border(
        bottom: showBottomBorder
            ? BorderSide(color: Colors.white.withOpacity(0.10), width: 0.6)
            : BorderSide.none,
        top: showTopBorder
            ? BorderSide(color: Colors.white.withOpacity(0.10), width: 0.6)
            : BorderSide.none,
      ),
    );
  }

  /// Apple Minimalist Ambient Shadow
  static List<BoxShadow> depthShadow({
    double depth = 6.0,
    Color? glowColor,
    double glowOpacity = 0.15,
    Color shadowColor = Colors.black,
  }) {
    return [
      BoxShadow(
        color: shadowColor.withOpacity(0.40),
        blurRadius: depth * 1.6,
        offset: Offset(0, depth * 0.4),
      ),
      if (glowColor != null)
        BoxShadow(
          color: glowColor.withOpacity(glowOpacity),
          blurRadius: depth * 2.0,
          offset: Offset(0, depth * 0.3),
        ),
    ];
  }

  /// Apple Pill / Capsule Decoration
  static BoxDecoration pill3DDecoration({
    Color backgroundColor = darkCard,
    Color? borderColor,
    bool isSelected = false,
    Color? glowColor,
    double borderRadius = 20.0,
  }) {
    return BoxDecoration(
      color: isSelected ? appleBlue : backgroundColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isSelected
            ? Colors.transparent
            : (borderColor ?? Colors.white.withOpacity(0.12)),
        width: 0.6,
      ),
      boxShadow: isSelected
          ? [
              BoxShadow(
                color: appleBlue.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ]
          : null,
    );
  }

  /// Apple Floating Rounded Navbar Decoration
  static BoxDecoration floatingNavbarDecoration({
    Color backgroundColor = glassSurfaceFloating,
    double borderRadius = 34.0,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? Colors.white.withOpacity(0.18),
        width: 0.75,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.55),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: appleBlue.withOpacity(0.10),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Apple Glass Capsule Decoration
  static BoxDecoration glassCapsuleDecoration({
    Color backgroundColor = const Color(0xD91C1C1E),
    Color? borderColor,
    double borderRadius = 28.0,
    double depth = 10.0,
    Color? glowColor,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? Colors.white.withOpacity(0.14),
        width: 0.6,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: depth,
          offset: const Offset(0, 3),
        ),
        if (glowColor != null)
          BoxShadow(
            color: glowColor.withOpacity(0.2),
            blurRadius: depth * 1.5,
            offset: const Offset(0, 2),
          ),
      ],
    );
  }

  /// General Glassmorphic Card Decoration
  static BoxDecoration glassCardDecoration({
    double borderRadius = 18.0,
    Color backgroundColor = glassSurface,
    Color? borderColor,
    double borderWidth = 0.6,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? Colors.white.withOpacity(0.12),
        width: borderWidth,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.35),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = ThemeData.dark().textTheme;
    final textTheme = GoogleFonts.interTextTheme(baseTextTheme).apply(
      bodyColor: darkTextPrimary,
      displayColor: darkTextPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: appleBlue,
        secondary: appleBlue,
        surface: darkCard,
        error: roseDanger,
        onPrimary: Colors.white,
        onSurface: darkTextPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: darkTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withOpacity(0.08), width: 0.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: appleBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: appleBlue,
          side: const BorderSide(color: appleBlue, width: 1.0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: -0.2,
          ),
        ),
      ),
      dividerColor: darkCardBorder,
    );
  }
}
