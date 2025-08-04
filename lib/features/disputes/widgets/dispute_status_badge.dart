import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';

/// Status badge widget for dispute list items
class DisputeStatusBadge extends StatelessWidget {
  final String status;

  const DisputeStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8, 
        vertical: 2
      ),
      decoration: BoxDecoration(
        color: _getStatusBackgroundColor(status),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getStatusText(status),
        style: TextStyle(
          color: _getStatusTextColor(status),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getStatusBackgroundColor(String status) {
    switch (status.toLowerCase()) {
      case 'in-progress':
        return AppTheme.statusSuccessBackground.withValues(alpha: 0.3);
      case 'resolved':
        return AppTheme.statusSettledBackground.withValues(alpha: 0.3);
      case 'closed':
        return AppTheme.statusInactiveBackground.withValues(alpha: 0.3);
      default:
        return AppTheme.statusPendingBackground.withValues(alpha: 0.3);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'in-progress':
        return AppTheme.statusSuccessText;
      case 'resolved':
        return AppTheme.statusSettledText;
      case 'closed':
        return AppTheme.statusInactiveText;
      default:
        return AppTheme.statusPendingText;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'in-progress':
        return 'In-progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return 'In-progress';
    }
  }
}
