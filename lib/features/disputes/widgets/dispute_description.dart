import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';

/// Description widget for dispute list items
class DisputeDescription extends StatelessWidget {
  final String description;

  const DisputeDescription({super.key, required this.description});

  @override
  Widget build(BuildContext context) {
    return Text(
      description,
      style: TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 13,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}
