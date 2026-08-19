import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // PREMIUM WARM STONE & AMBER Theme
  
  // Stone Palette (Warm Grays)
  static const Color primary = Color(0xFF292524); // Stone 800
  static const Color primaryContainer = Color(0xFF44403C); // Stone 700
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFF5F5F4); // Stone 100

  // Amber Palette (Rich Gold)
  static const Color secondary = Color(0xFFD97706); // Amber 600
  static const Color secondaryContainer = Color(0xFFFDE68A); // Amber 200
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF78350F); // Amber 900

  static const Color accent = Color(0xFFF59E0B); // Amber 500
  static const Color onAccent = Color(0xFFFFFBEB);

  static const Color error = Color(0xFFDC2626); // Red 600
  static const Color errorContainer = Color(0xFFFEE2E2); // Red 100
  static const Color onError = Colors.white;
  static const Color onErrorContainer = Color(0xFF7F1D1D); // Red 900

  // Neutral Backgrounds
  static const Color background = Color(0xFFF5F5F4); // Stone 100
  static const Color onBackground = Color(0xFF1C1917); // Stone 900

  static const Color surface = Color(0xFFFAFAF9); // Stone 50
  static const Color surfaceContainerLowest = Colors.white;
  static const Color surfaceContainerLow = Color(0xFFFAFAF9); // Stone 50
  static const Color surfaceContainer = Color(0xFFF5F5F4); // Stone 100
  static const Color surfaceContainerHigh = Color(0xFFE7E5E4); // Stone 200
  static const Color surfaceContainerHighest = Color(0xFFD6D3D1); // Stone 300
  
  static const Color onSurface = Color(0xFF1C1917); // Stone 900
  static const Color onSurfaceVariant = Color(0xFF57534E); // Stone 500
  static const Color outline = Color(0xFFA8A29E); // Stone 400
  static const Color outlineVariant = Color(0xFFD6D3D1); // Stone 300

  // Compatibility members for existing screens
  static const Color tertiary = accent;
  static const Color tertiaryContainer = secondaryContainer;
  static const Color surfaceVariant = surfaceContainer;
  static const Color tertiaryFixed = secondaryContainer;
  static const Color onTertiaryFixed = onSecondaryContainer;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        error: error,
        onError: onError,
        errorContainer: errorContainer,
        onErrorContainer: onErrorContainer,
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        outlineVariant: outlineVariant,
        tertiary: accent,
        onTertiary: onAccent,
      ),
      scaffoldBackgroundColor: background,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: primary),
        displayMedium: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: primary),
        displaySmall: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: primary),
        headlineLarge: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: primary),
        headlineMedium: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: primary),
        headlineSmall: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: primary),
        titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: onSurface),
        titleMedium: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: onSurface),
        titleSmall: GoogleFonts.outfit(fontWeight: FontWeight.w500, color: onSurface),
        bodyLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.normal, color: onSurface),
        bodyMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.normal, color: onSurface),
        bodySmall: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.normal, color: onSurfaceVariant),
        labelLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: outline),
        labelMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, color: outline),
        labelSmall: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.normal, color: outline),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceContainerLowest,
        foregroundColor: primary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          color: primary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: primary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: secondary,
          foregroundColor: onSecondary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: secondary, width: 2),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(color: onSurfaceVariant),
        hintStyle: GoogleFonts.plusJakartaSans(color: outline),
      ),
      cardTheme: CardThemeData(
        color: surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: outlineVariant, width: 1),
        ),
      ),
    );
  }
}
