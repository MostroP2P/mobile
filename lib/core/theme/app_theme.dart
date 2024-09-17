import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  static ThemeData get darkTheme {
    const ColorScheme colorScheme = ColorScheme.dark(
      primary: AppColors.mostroGreen,
      secondary: AppColors.yellow,
      surface: AppColors.dark2,
      error: AppColors.red1,
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      primaryColor: AppColors.mostroGreen,
      scaffoldBackgroundColor: AppColors.dark1,
      appBarTheme: AppBarTheme(
        color: AppColors.dark2,
        titleTextStyle: AppTextStyles.appBarTitle,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.dark2,
        selectedItemColor: AppColors.mostroGreen,
        unselectedItemColor: AppColors.grey2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.mostroGreen,
          foregroundColor: Colors.white,
          textStyle: AppTextStyles.buttonText,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: AppColors.grey,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
