import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:mostro_mobile/core/app_theme.dart';

class CustomElevatedButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double minFontSize;
  final double? width;
  final TextStyle? textStyle;

  const CustomElevatedButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.padding,
    this.backgroundColor,
    this.foregroundColor,
    this.minFontSize = 12.0,
    this.width,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final buttonWidget = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: foregroundColor ?? Colors.black,
        backgroundColor: backgroundColor ?? AppTheme.mostroGreen,
        padding:
            padding ?? const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
      ),
      child: AutoSizeText(
        text,
        style: textStyle ?? Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: foregroundColor ?? Colors.black,
        ),
        minFontSize: minFontSize,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    
    return width != null ? SizedBox(width: width, child: buttonWidget) : buttonWidget;
  }
}
