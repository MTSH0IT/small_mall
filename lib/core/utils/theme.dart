import 'package:flutter/material.dart';

class AppColors {
  static const Color surface = Color(0xFFFAF8F5);
  static const Color surfaceDark = Color(0xFF1C1B19);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF2F6F5E);
  static const Color primaryDark = Color(0xFF1F4E42);
  static const Color accent = Color(0xFFC9A227);
  static const Color danger = Color(0xFFC1443C);
  static const Color success = Color(0xFF3F8F5F);
  static const Color textPrimary = Color(0xFF211F1C);
  static const Color textSecondary = Color(0xFF6B6560);
  static const Color border = Color(0xFFE7E2DB);

  static final BoxDecoration cardDecoration = BoxDecoration(
    color: AppColors.surfaceElevated,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: AppColors.border),
  );
}

class AppTheme {
  static const String _fontFamily = 'Cairo';

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.surface,
      dividerColor: AppColors.border,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        labelSmall: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }

  static TextStyle numericStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color color = AppColors.textPrimary,
  }) {
    return TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color);
  }
}
