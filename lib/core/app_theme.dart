import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Original colors
  static const Color grey = Color(0xFFCCCCCC);
  static const Color mostroGreen = Color(0xFF8CC63F);
  static const Color dark1 = Color(0xFF1D212C);
  static const Color grey2 = Color(0xFF92949A);
  static const Color yellow = Color(0xFFF3CA29);
  static const Color red1 = Color(0xFFD84D4D);
  static const Color dark2 = Color(0xFF303544);
  static const Color cream1 = Color(0xFFF9F8F1);
  static const Color red2 = Color(0xFFEF6A6A);

  // New colors

  // Colors for backgrounds
  static const Color backgroundDark = Color(0xFF171A23); // Main dark background
  static const Color backgroundCard = Color(0xFF1E2230);
  static const Color backgroundInput = Color(0xFF252A3A);
  static const Color backgroundInactive = Color(0xFF2A3042);
  static const Color backgroundNavBar = Color(0xFF1A1F2C);

  // Colors for text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFCCCCCC);
  static const Color textInactive = Color(0xFF8A8D98);
  static const Color textSubtle = Colors.white60;

  // Colors for actions
  static const Color buyColor = mostroGreen;
  static const Color sellColor = Color(0xFFFF8A8A);
  static const Color activeColor = mostroGreen;
  static const Color purpleAccent = Color(0xFF764BA2);
  static const Color purpleButton = Color(0xFF7856AF);

  // Colors for states
  static const Color statusSuccess = mostroGreen;
  static const Color statusWarning = Color(0xFFF3CA29);
  static const Color statusError = Color(0xFFEF6A6A);
  static const Color statusActive = mostroGreen;
  static const Color statusInfo = Color.fromARGB(255, 42, 123, 214);
  
  // Colors for role chips
  static const Color createdByYouChip = Color(0xFF1565C0); // Colors.blue.shade700
  static const Color takenByYouChip = Color(0xFF00796B);   // Colors.teal.shade700
  static const Color premiumPositiveChip = Color(0xFF388E3C); // Colors.green.shade700
  static const Color premiumNegativeChip = Color(0xFFC62828); // Colors.red.shade700
  
  // Colors for status chips
  static const Color statusPendingBackground = Color(0xFF854D0E);
  static const Color statusPendingText = Color(0xFFFCD34D);
  static const Color statusWaitingBackground = Color(0xFF7C2D12);
  static const Color statusWaitingText = Color(0xFFFED7AA);
  static const Color statusActiveBackground = Color(0xFF1E3A8A);
  static const Color statusActiveText = Color(0xFF93C5FD);
  static const Color statusSuccessBackground = Color(0xFF065F46);
  static const Color statusSuccessText = Color(0xFF6EE7B7);
  static const Color statusDisputeBackground = Color(0xFF7F1D1D);
  static const Color statusDisputeText = Color(0xFFFCA5A5);
  static const Color statusSettledBackground = Color(0xFF581C87);
  static const Color statusSettledText = Color(0xFFC084FC);
  static const Color statusInactiveBackground = Color(0xFF1F2937); // Colors.grey.shade800
  static const Color statusInactiveText = Color(0xFFD1D5DB);     // Colors.grey.shade300
  
  // Text colors
  static const Color secondaryText = Color(0xFFBDBDBD);  // Colors.grey.shade400

  // Padding  and margin constants
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
      scaffoldBackgroundColor: backgroundDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
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
          foregroundColor: Colors.black,
          backgroundColor: mostroGreen,
          textStyle: GoogleFonts.robotoCondensed(
            fontWeight: FontWeight.w500,
            fontSize: 14.0,
          ),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
          fixedSize: const Size.fromHeight(48),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
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
      cardTheme: CardThemeData(
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
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return GoogleFonts.robotoCondensedTextTheme(
      const TextTheme(
        displayLarge: TextStyle(
          fontSize: 24.0,
        ),
        displayMedium: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 20.0,
        ),
        displaySmall: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16.0,
        ),
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16.0,
        ),
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14.0,
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16.0,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 18.0,
        ),
        bodyLarge: TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 16.0,
        ),
        bodyMedium: TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 14.0,
        ),
        labelLarge: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14.0,
        ),
      ),
    ).apply(
      bodyColor: cream1,
      displayColor: cream1,
    );
  }

  // helpers for shadows
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.7),
          blurRadius: 15,
          offset: const Offset(0, 5),
          spreadRadius: -3,
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.07),
          blurRadius: 1,
          offset: const Offset(0, -1),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get buttonShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 6,
          offset: const Offset(0, 3),
          spreadRadius: -2,
        ),
      ];
}
