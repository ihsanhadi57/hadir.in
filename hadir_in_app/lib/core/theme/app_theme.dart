import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// hadir.in App Theme — The Digital Concierge
/// High-end Corporate, Seamless Flow.
class AppTheme {
  AppTheme._();

  // ─── Tonal Layers (No-Line Philosophy) ───
  static const Color background = Color(0xFFF9F9FF); // Layer 0
  static const Color surfaceContainerLow = Color(0xFFF3F4F6); // Layer 1
  static const Color card = Color(0xFFFFFFFF); // Layer 2 (surface-container-lowest)
  static const Color surfaceContainerHigh = Color(0xFFE5E7EB); // For recessed areas / inputs
  
  // ─── Accent & Branding ───
  static const Color primary = Color(0xFF002766); // Deep Navy
  static const Color primaryContainer = Color(0xFFFF6F61); // Vibrant Coral
  static const Color inverseSurface = Color(0xFF0F172A); // Even darker Navy
  static const Color inverseOnSurface = Color(0xFFFFFFFF);

  // ─── Text & Ink ───
  static const Color textPrimary = Color(0xFF141B2B); // on-surface
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF6B7280); // outline-variant fallback

  // ─── Semantic ───
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFEE2E2);

  // ─── Shadows ───
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF141B2B).withValues(alpha: 0.06),
          blurRadius: 32,
          offset: const Offset(0, 8),
        ),
      ];

  // ─── Theme Data ───
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: primaryContainer,
        surface: card,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -1,
        ),
        displayMedium: baseTextTheme.displayMedium?.copyWith(
          fontSize: 28, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.5,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          fontSize: 16, fontWeight: FontWeight.w500, color: textPrimary,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        labelMedium: baseTextTheme.labelMedium?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textMuted,
          letterSpacing: 0.5, // Less extreme letter spacing for corporate
        ),
        labelSmall: baseTextTheme.labelSmall?.copyWith(
          fontSize: 10, fontWeight: FontWeight.w600, color: textMuted,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none, // No lines!
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0x66002766), width: 2), // Ghost Navy
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none, // Error uses container background mostly, but fallback border
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: textMuted.withValues(alpha: 0.8),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
        errorStyle: GoogleFonts.plusJakartaSans(
          color: error, fontSize: 12, fontWeight: FontWeight.w500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15, fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8), // rounded-md
          ),
          minimumSize: const Size(double.infinity, 52),
        ),
      ),
    );
  }
}
