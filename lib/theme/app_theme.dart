import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Цветовая палитра и типографика — тёмная мистическая эстетика.
class AppColors {
  static const bgDark = Color(0xFF0D0221);
  static const bgMid = Color(0xFF1A0B2E);
  static const gold = Color(0xFFD4AF37);
  static const goldBright = Color(0xFFF4C430);
  static const indigo = Color(0xFF6C3FBB);
  static const textWarm = Color(0xFFF5F0E8);
  static const textMuted = Color(0xFFB4A9D6);
  static const cardGradientTop = Color(0xFF3C3489);
  static const cardGradientBottom = Color(0xFF1A0B2E);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bgDark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.gold,
        secondary: AppColors.indigo,
        surface: AppColors.bgMid,
      ),
      textTheme: TextTheme(
        // Заголовки и названия карт — декоративный serif
        headlineMedium: GoogleFonts.cormorantGaramond(
          color: AppColors.textWarm,
          fontSize: 22,
          fontStyle: FontStyle.italic,
        ),
        titleLarge: GoogleFonts.cormorantGaramond(
          color: AppColors.goldBright,
          fontSize: 20,
        ),
        // Основной текст — читаемый sans-serif
        bodyLarge: GoogleFonts.nunitoSans(
          color: AppColors.textWarm,
          fontSize: 15,
          height: 1.6,
        ),
        bodyMedium: GoogleFonts.nunitoSans(
          color: AppColors.textMuted,
          fontSize: 13,
        ),
      ),
      fontFamily: GoogleFonts.nunitoSans().fontFamily,
    );
  }
}
