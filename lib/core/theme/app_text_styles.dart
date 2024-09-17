import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  static const String fontFamily = 'Roboto Condensed';

  static TextStyle bodyLarge = const TextStyle(
    fontFamily: fontFamily,
    color: AppColors.cream1,
    fontWeight: FontWeight.normal,
  );

  static TextStyle bodyMedium = const TextStyle(
    fontFamily: fontFamily,
    color: AppColors.grey,
    fontWeight: FontWeight.w500,
  );

  static TextStyle buttonText = const TextStyle(
    fontFamily: fontFamily,
    color: Colors.white,
    fontWeight: FontWeight.bold,
  );

  static TextStyle appBarTitle = const TextStyle(
    fontFamily: fontFamily,
    color: Colors.white,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );
}
