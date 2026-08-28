import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Дизайны палитр (Өнгөний палитр хэсгээс авсан)
class AppColors {
  static const primary = Color(0xFF6C5CE7); // Ягаан-нил ягаан үндсэн өнгө
  static const secondary = Color(0xFF9B59B6);
  static const background = Color(0xFF0D0D12); // Хамгийн харанхуй дэвсгэр
  static const surface = Color(0xFF1A1A23); // Карт, панелийн дэвсгэр
  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFF8E8E93);
}

/// Апп даяар ашиглах theme
final ThemeData appTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    surface: AppColors.surface,
  ),
  // google_fonts нь Poppins-ийг runtime-д татаж, textTheme даяар тавьж өгнө
  textTheme: GoogleFonts.poppinsTextTheme(
    ThemeData(brightness: Brightness.dark).textTheme,
  ).copyWith(
    titleLarge: GoogleFonts.poppins(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w700, // Bold
    ),
    titleMedium: GoogleFonts.poppins(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600, // SemiBold
    ),
    bodyMedium: GoogleFonts.poppins(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w400, // Regular
    ),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.background,
    elevation: 0,
    foregroundColor: AppColors.textPrimary,
    titleTextStyle: GoogleFonts.poppins(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
      fontSize: 18,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
  ),
);