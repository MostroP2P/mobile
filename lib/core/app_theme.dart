import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // COLORES ORIGINALES - Mantener para componentes existentes
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

  // NUEVOS COLORES - Organizados por categorías

  // Colores para fondos
  static const Color backgroundDark =
      Color(0xFF171A23); // Fondo principal oscuro
  static const Color backgroundCard = Color(0xFF1E2230); // Fondo de tarjetas
  static const Color backgroundInput = Color(0xFF252A3A); // Fondo de inputs
  static const Color backgroundInactive = Color(0xFF2A3042); // Fondo inactivo
  static const Color backgroundNavBar =
      Color(0xFF1A1F2C); // Fondo de la barra de navegación

  // Colores para texto
  static const Color textPrimary = Colors.white; // Texto principal
  static const Color textSecondary = Color(0xFFCCCCCC); // Texto secundario
  static const Color textInactive = Color(0xFF8A8D98); // Texto inactivo
  static const Color textSubtle = Colors.white60; // Texto sutil

  // Colores de acción
  static const Color buyColor = Color(0xFF8CC63F); // Color para comprar (verde)
  static const Color sellColor = Color(0xFFEA384C); // Color para vender (rojo)
  static const Color activeColor = Color(0xFF8CC541); // Color activo (verde)

  // Colores para estados
  static const Color statusSuccess = Color(0xFF8CC541); // Estado de éxito
  static const Color statusWarning = Color(0xFFF3CA29); // Estado de advertencia
  static const Color statusError = Color(0xFFE45A5A); // Estado de error
  static const Color statusActive = Color(0xFF8CC541); // Estado activo

  // Padding y Margin constantes
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
      scaffoldBackgroundColor: backgroundDark, // Actualizado al nuevo color
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
          foregroundColor: cream1,
          backgroundColor: mostroGreen,
          textStyle: GoogleFonts.robotoCondensed(
            fontWeight: FontWeight.w500,
            fontSize: 14.0,
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

  // Helpers para crear sombras consistentes
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.7),
          blurRadius: 15,
          offset: const Offset(0, 5),
          spreadRadius: -3,
        ),
        BoxShadow(
          color: Colors.white.withOpacity(0.07),
          blurRadius: 1,
          offset: const Offset(0, -1),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get buttonShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 6,
          offset: const Offset(0, 3),
          spreadRadius: -2,
        ),
      ];
}
