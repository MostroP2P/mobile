import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color Definitions
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

  // Padding and Margin Constants
  static const EdgeInsets smallPadding = EdgeInsets.all(8.0);
  static const EdgeInsets mediumPadding =
      EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
  static const EdgeInsets largePadding = EdgeInsets.all(24.0);

  static const EdgeInsets smallMargin = EdgeInsets.all(4.0);
  static const EdgeInsets mediumMargin =
      EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0);
  static const EdgeInsets largeMargin = EdgeInsets.all(20.0);

  static ThemeData get theme {
    return ThemeData(
      hoverColor: dark1,
      primaryColor: mostroGreen,
      scaffoldBackgroundColor: dark1,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: dark2,
        titleTextStyle: GoogleFonts.robotoCondensed(
          fontWeight: FontWeight.bold,
          fontSize: 20.0,
          color: cream1,
        ),
        contentTextStyle: GoogleFonts.robotoCondensed(
          fontWeight: FontWeight.w400,
          fontSize: 16.0,
          color: grey,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      textTheme: _buildTextTheme(),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: AppTheme.cream1,
          backgroundColor: mostroGreen,
          textStyle: GoogleFonts.robotoCondensed(
            fontWeight: FontWeight.w500,
            fontSize: 16.0,
          ),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: mostroGreen,
          textStyle: GoogleFonts.robotoCondensed(
            fontWeight: FontWeight.w500,
            fontSize: 14.0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: mostroGreen,
          side: const BorderSide(color: mostroGreen),
          textStyle: GoogleFonts.robotoCondensed(
            fontWeight: FontWeight.w500,
            fontSize: 14.0,
          ),
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
      cardTheme: CardTheme(
        color: dark2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: dark2),
        ),
      ),
      iconTheme: const IconThemeData(
        color: cream1,
        size: 24.0,
      ),
      listTileTheme: ListTileThemeData(
          titleTextStyle: TextStyle(
        color: grey,
        fontFamily: GoogleFonts.robotoCondensed().fontFamily,
      )),
    );
  }

  static TextTheme _buildTextTheme() {
    return GoogleFonts.robotoCondensedTextTheme(
      const TextTheme(
        displayLarge: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 24.0,
        ), // For larger titles
        displayMedium: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 20.0,
        ), // For medium titles
        displaySmall: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16.0,
        ), // For smaller titles
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16.0,
        ), // For subtitles
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14.0,
        ), // For secondary text
        titleMedium: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16.0,
        ), // For form labels
        titleLarge: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 18.0,
        ), // For form labels
        bodyLarge: TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 16.0,
        ), // For body text
        bodyMedium: TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 14.0,
        ), // For smaller body text
        labelLarge: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14.0,
        ), // For buttons and labels
      ),
    ).apply(
      bodyColor: cream1,
      displayColor: cream1,
    );
  }
}
