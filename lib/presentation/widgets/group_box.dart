import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/theme/app_theme.dart';

class GroupBox extends StatelessWidget {
  final String title;
  final Widget child;

  const GroupBox({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none, // Allow overflow of title
      children: [
        // The group box with content
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              child,
            ],
          ),
        ),
        // The title widget overlapping the border
        Positioned(
          top: -10, // Adjust this value for how much you want to overlap
          left: 10, // Adjust horizontal alignment if needed
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            color: Colors.white, // This covers the border underneath the title
            child: Text(
              title,
              style: TextStyle(
                color: AppTheme.mostroGreen,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
