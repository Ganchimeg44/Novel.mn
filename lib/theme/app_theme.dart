import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Novel.mn-ийн НЭГДСЭН дизайны палитр.
///
/// АНХААРУУЛГА: `primary`, `secondary`, `background`, `surface`,
/// `textPrimary`, `textSecondary` гэсэн 6 талбар нь төслийн БҮХ дэлгэцэд
/// (novel_list_screen, novel_detail_screen, chapter_reader_screen,
/// login/register/otp, profile_screen гэх мэт) өргөнөөр ашиглагдсан тул
/// НЭРИЙГ НЬ ХЭВЭЭР үлдээж, зөвхөн доорх шинэ, "premium dark fantasy"
/// загварт тохирсон hex утгаар шинэчилсэн. Доор нэмэгдсэн бусад бүх
/// талбар (gold, deepPurple, textMuted, readerBackground гэх мэт)
/// ЗӨВХӨН НЭМЭЛТ бөгөөд одоо байгаа кодод нөлөөлөхгүй.
class AppColors {
  // --- Одоо байгаа 6 үндсэн талбар (утга нь шинэчлэгдсэн) ---
  static const primary = Color(0xFF7C4DFF); // Primary Purple
  static const secondary = Color(0xFFD9A441); // Gold — ColorScheme.secondary
  static const background = Color(0xFF070B18); // Background
  static const surface = Color(0xFF12182A); // Surface
  static const textPrimary = Color(0xFFF7F3EA); // Text Primary
  static const textSecondary = Color(0xFFAAAFC0); // Text Secondary

  // --- Шинэ, premium дизайны системд зориулсан нэмэлт талбарууд ---
  static const backgroundSecondary = Color(0xFF0D1224); // Secondary Background
  static const surfaceElevated = Color(0xFF181F35); // Surface Elevated
  static const primaryLight = Color(0xFF9B6BFF); // Primary Purple Light
  static const deepPurple = Color(0xFF5C2FE6); // Deep Purple
  static const gold = Color(0xFFD9A441); // Gold
  static const goldLight = Color(0xFFF1C66D); // Gold Light
  static const textMuted = Color(0xFF73798C); // Text Muted
  static const border = Color(0xFF262E46); // Border
  static const success = Color(0xFF48C78E); // Success
  static const danger = Color(0xFFFF5C70); // Danger

  // Унших дэлгэцийн (light/cream reading mode) өнгө
  static const readerBackground = Color(0xFFF4EAD6);
  static const readerText = Color(0xFF33291F);
  static const readerMuted = Color(0xFF7A6B5B);

  // Эрхийн (VIP/VVIP/+18) өнгөт accent
  static const accent18 = Color(0xFF8C4DFF);
  static const vipAccent = Color(0xFF7C4DFF);
  static const vvipAccent = Color(0xFFD9A441);
}

/// Зай/хэмжээний тогтмол утгууд (4-ийн үржвэрийн spacing scale).
class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
}

/// Картны булангийн радиусын тогтмол утгууд.
class AppRadius {
  static const card = 16.0; // default
  static const premium = 20.0; // premium card
  static const hero = 24.0; // hero banner
  static const button = 14.0;
  static const input = 14.0;
}

/// Desktop/web дэвсгэр дээрх агуулгын хамгийн их өргөнүүд.
class AppLayout {
  static const contentMaxWidth = 1160.0;
  static const authMaxWidth = 460.0;
  static const profileMaxWidth = 760.0;
  static const readerMaxWidth = 720.0;
}

/// Зохиолын нэр/premium гарчигт зориулсан serif фонт (Playfair Display).
/// Энгийн UI текстэд google_fonts-ийн Poppins-ийг үргэлжлүүлэн ашиглана.
class AppTypography {
  static TextStyle appLogo({Color color = AppColors.gold}) =>
      GoogleFonts.playfairDisplay(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: 30,
      );

  static TextStyle novelTitle({
    Color color = AppColors.textPrimary,
    double fontSize = 20,
  }) =>
      GoogleFonts.playfairDisplay(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: fontSize,
      );

  static TextStyle pageTitle({Color color = AppColors.textPrimary}) =>
      GoogleFonts.poppins(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: 24,
      );

  static TextStyle sectionTitle({Color color = AppColors.textPrimary}) =>
      GoogleFonts.poppins(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 18,
      );

  static TextStyle cardTitle({Color color = AppColors.textPrimary}) =>
      GoogleFonts.poppins(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      );

  static TextStyle body({Color color = AppColors.textSecondary}) =>
      GoogleFonts.poppins(
        color: color,
        fontWeight: FontWeight.w400,
        fontSize: 14,
      );

  static TextStyle meta({Color color = AppColors.textMuted}) =>
      GoogleFonts.poppins(
        color: color,
        fontWeight: FontWeight.w500,
        fontSize: 12,
      );
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
      minimumSize: const Size.fromHeight(50),
      padding: const EdgeInsets.symmetric(vertical: 16),
      textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    labelStyle: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.input),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.input),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.input),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
  ),
);