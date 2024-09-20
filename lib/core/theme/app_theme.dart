import 'package:flutter/material.dart';

class AppTheme {
  static const Color grey = Color(0xFFCCCCCC);
  static const Color mostroGreen = Color(0xFF8CC541);
  static const Color dark1 = Color(0xFF1D212C);
  static const Color grey2 = Color(0xFF92949A);
  static const Color yellow = Color(0xFFF3CA29);
  static const Color red1 = Color(0xFFCA3C3C);
  static const Color dark2 = Color(0xFF303544);
  static const Color cream1 = Color(0xFFF9F8F1);
  static const Color red2 = Color(0xFFE45A5A);
  static const Color green2 = Color(0xFF739C3D);

  static ThemeData get theme {
    return ThemeData(
      primaryColor: mostroGreen,
      scaffoldBackgroundColor: dark1,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontFamily: 'RobotoCondensed', fontWeight: FontWeight.w700),
        displayMedium: TextStyle(
            fontFamily: 'RobotoCondensed', fontWeight: FontWeight.w700),
        displaySmall: TextStyle(
            fontFamily: 'RobotoCondensed', fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(
            fontFamily: 'RobotoCondensed', fontWeight: FontWeight.w700),
        headlineSmall: TextStyle(
            fontFamily: 'RobotoCondensed', fontWeight: FontWeight.w500),
        titleLarge: TextStyle(
            fontFamily: 'RobotoCondensed', fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(
            fontFamily: 'RobotoCondensed', fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(
            fontFamily: 'RobotoCondensed', fontWeight: FontWeight.w400),
        labelLarge: TextStyle(
            fontFamily: 'RobotoCondensed', fontWeight: FontWeight.w500),
      ).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: mostroGreen,
          textStyle: const TextStyle(
              fontFamily: 'RobotoCondensed', fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        labelStyle: TextStyle(color: grey),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: grey),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: mostroGreen),
        ),
      ),
    );
  }
}
