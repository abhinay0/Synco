import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppleTheme {
  // System Apple Colors
  static const Color systemBlue = Color(0xFF007AFF);
  static const Color systemIndigo = Color(0xFF5856D6);
  static const Color systemPurple = Color(0xFFAF52DE);
  static const Color systemPink = Color(0xFFFF2D55);
  static const Color systemOrange = Color(0xFFFF9500);
  static const Color systemGreen = Color(0xFF34C759);
  static const Color systemTeal = Color(0xFF5AC8FA);

  // Backgrounds & Surfaces
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkElevatedSurface = Color(0xFF1C1C1E);
  static const Color darkSecondarySurface = Color(0xFF2C2C2E);
  static const Color darkGlassBackground = Color(0xCC1A1A1E);

  static const Color lightBackground = Color(0xFFF2F2F7);
  static const Color lightElevatedSurface = Color(0xFFFFFFFF);
  static const Color lightSecondarySurface = Color(0xFFE5E5EA);
  static const Color lightGlassBackground = Color(0xCCFFFFFF);

  // Optical Typography (Tight tracking matching SF Pro)
  static TextStyle largeTitle({Color? color}) => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: color,
      );

  static TextStyle title1({Color? color}) => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: color,
      );

  static TextStyle title2({Color? color}) => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: color,
      );

  static TextStyle headline({Color? color}) => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: color,
      );

  static TextStyle body({Color? color}) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle subheadline({Color? color}) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.1,
        color: color,
      );

  static TextStyle caption({Color? color}) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.0,
        color: color,
      );

  static ThemeData darkTheme({Color accentColor = systemBlue}) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: ColorScheme.dark(
        primary: accentColor,
        secondary: systemIndigo,
        surface: darkElevatedSurface,
      ),
      cardTheme: CardThemeData(
        color: darkElevatedSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.1),
        thickness: 0.5,
      ),
    );
  }

  static ThemeData lightTheme({Color accentColor = systemBlue}) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: ColorScheme.light(
        primary: accentColor,
        secondary: systemIndigo,
        surface: lightElevatedSurface,
      ),
      cardTheme: CardThemeData(
        color: lightElevatedSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.black.withValues(alpha: 0.08),
        thickness: 0.5,
      ),
    );
  }
}
