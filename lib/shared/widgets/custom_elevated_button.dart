import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';

class CustomElevatedButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const CustomElevatedButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.padding,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: foregroundColor ?? Colors.white,
        backgroundColor: backgroundColor ?? AppTheme.mostroGreen,
        textStyle: Theme.of(context).textTheme.labelLarge,
        padding: padding ?? const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
      ),
      child: Text(text),
    );
  }
}
