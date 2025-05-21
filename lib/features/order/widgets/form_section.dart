import 'package:flutter/material.dart';

class FormSection extends StatelessWidget {
  final String title;
  final Widget icon;
  final Color iconBackgroundColor;
  final Widget child;
  final Widget? extraContent;

  const FormSection({
    super.key,
    required this.title,
    required this.icon,
    required this.iconBackgroundColor,
    required this.child,
    this.extraContent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: icon),
                ),
                const SizedBox(width: 16),
                Expanded(child: child),
              ],
            ),
          ),
          if (extraContent != null) extraContent!,
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.1),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ],
      ),
    );
  }
}
