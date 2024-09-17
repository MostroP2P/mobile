import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.mostroGreen,
      scaffoldBackgroundColor: AppColors.dark1,
      appBarTheme: AppBarTheme(
        color: AppColors.dark2,
        titleTextStyle: AppTextStyles.bodyLarge.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.dark2,
        selectedItemColor: AppColors.mostroGreen,
        unselectedItemColor: AppColors.grey2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.mostroGreen,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: AppTextStyles.buttonText,
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
      colorScheme:
          ColorScheme.fromSwatch().copyWith(secondary: AppColors.yellow),
    );
  }
}
