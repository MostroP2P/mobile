import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;
  final EdgeInsets padding;
  final Color? color;
  final BorderSide? borderSide;

  const CustomCard({
    super.key,
    required this.child,
    this.margin = EdgeInsets.zero,
    this.padding = EdgeInsets.zero,
    this.color,
    this.borderSide,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color ?? const Color(0xFF1D212C),
      margin: margin,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: borderSide ?? BorderSide(color: const Color(0xFF1D212C)),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
