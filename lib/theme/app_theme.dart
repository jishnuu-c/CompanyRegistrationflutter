import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors matching the Laravel app design with modern mobile enhancements
  static const Color primaryNavy = Color(0xFF0D3B66);
  static const Color darkNavy = Color(0xFF072A4A);
  static const Color buttonNavy = Color(0xFF0A4D8C);
  static const Color buttonHoverNavy = Color(0xFF0F5EA8);
  static const Color cardBg = Color(0xFFD4EAF2);
  static const Color cardBgLight = Color(0xFFEAF5F9);
  static const Color cardBorder = Color(0xFF0D3B66);
  static const Color inputBg = Colors.white;
  static const Color inputBorder = Color(0xFFB4C8D8);
  static const Color inputFocusBorder = Color(0xFF0D3B66);
  static const Color surfaceBg = Color(0xFFF6F9FC);
  static const Color textDark = Color(0xFF142436);
  static const Color textMuted = Color(0xFF5A6E82);
  static const Color starGold = Color(0xFFFFB800);
  static const Color badgeBg = Color(0xFF0D3B66);

  static ThemeData get lightTheme {
    final baseFont = GoogleFonts.outfitTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: surfaceBg,
      primaryColor: primaryNavy,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryNavy,
        primary: primaryNavy,
        secondary: buttonNavy,
        surface: surfaceBg,
      ),
      textTheme: baseFont.copyWith(
        displayLarge: GoogleFonts.lora(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: primaryNavy,
        ),
        titleLarge: GoogleFonts.lora(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: primaryNavy,
        ),
        titleMedium: GoogleFonts.outfit(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 14,
          color: textDark,
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 13,
          color: textDark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonNavy,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.white, width: 1),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: inputBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: inputBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: primaryNavy, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        hintStyle: GoogleFonts.outfit(
          color: Colors.grey.shade400,
          fontSize: 13,
        ),
      ),
    );
  }
}
