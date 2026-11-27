import 'package:flutter/material.dart';

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
  // Шрифты встроены в приложение (assets/fonts), из интернета не загружаются.
  static const _serif = 'CormorantGaramond';
  static const _sans = 'NunitoSans';

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
        headlineMedium: TextStyle(
          fontFamily: _serif,
          color: AppColors.textWarm,
          fontSize: 22,
          fontStyle: FontStyle.italic,
        ),
        titleLarge: TextStyle(
          fontFamily: _serif,
          color: AppColors.goldBright,
          fontSize: 20,
        ),
        // Основной текст — читаемый sans-serif
        bodyLarge: TextStyle(
          fontFamily: _sans,
          color: AppColors.textWarm,
          fontSize: 15,
          height: 1.6,
        ),
        bodyMedium: TextStyle(
          fontFamily: _sans,
          color: AppColors.textMuted,
          fontSize: 13,
        ),
      ),
      fontFamily: _sans,
    );
  }
}
