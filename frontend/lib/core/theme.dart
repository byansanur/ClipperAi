// lib/core/theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Palette Warna
  static const Color darkBg = Color(0xFF0F0F12);       // Background pekat bernuansa ungu-abu
  static const Color cardBg = Color(0xFF181820);       // Background kartu / container
  static const Color primaryPurple = Color(0xFF8B5CF6); // Ungu neon modern
  static const Color accentCyan = Color(0xFF06B6D4);    // Cyan kontras untuk highlights
  static const Color textMain = Color(0xFFF3F4F6);     // Putih abu lembut
  static const Color textMuted = Color(0xFF9CA3AF);    // Abu-abu keterangan

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: primaryPurple,
      colorScheme: const ColorScheme.dark(
        primary: primaryPurple,
        secondary: accentCyan,
        surface: cardBg,
        background: darkBg,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: textMain,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textMain,
        ),
        bodyLarge: const TextStyle(fontSize: 16, color: textMain),
        bodyMedium: const TextStyle(fontSize: 14, color: textMuted),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBg.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryPurple.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryPurple, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
