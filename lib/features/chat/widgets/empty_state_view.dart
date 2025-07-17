import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';

class EmptyStateView extends StatelessWidget {
  final String message;

  const EmptyStateView({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: TextStyle(color: AppTheme.textSecondary),
      ),
    );
  }
}