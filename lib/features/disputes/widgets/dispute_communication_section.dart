import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';

class DisputeCommunicationSection extends StatelessWidget {
  const DisputeCommunicationSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Communication',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          // Communication messages will appear here when implemented
        ],
      ),
    );
  }
}
