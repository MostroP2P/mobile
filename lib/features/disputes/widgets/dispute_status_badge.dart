import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/generated/l10n.dart';

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
        _getStatusText(context, status),
        style: TextStyle(
          color: _getStatusTextColor(status),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Normalizes status string by trimming, lowercasing, and replacing spaces/underscores with hyphens
  String _normalizeStatus(String status) {
    if (status.isEmpty) return '';
    // Trim, lowercase, and replace spaces/underscores with hyphens
    return status.trim().toLowerCase().replaceAll(RegExp(r'[\s_]+'), '-');
  }

  Color _getStatusBackgroundColor(String status) {
    final s = _normalizeStatus(status);
    switch (s) {
      case 'initiated':
        return AppTheme.statusPendingBackground.withValues(alpha: 0.3);
      case 'in-progress':
        return AppTheme.statusSuccessBackground.withValues(alpha: 0.3);
      case 'resolved':
      case 'solved':
        return Colors.blue.withValues(alpha: 0.3);
      case 'closed':
        return AppTheme.statusInactiveBackground.withValues(alpha: 0.3);
      default:
        return AppTheme.statusPendingBackground.withValues(alpha: 0.3);
    }
  }

  Color _getStatusTextColor(String status) {
    final s = _normalizeStatus(status);
    switch (s) {
      case 'initiated':
        return AppTheme.statusPendingText;
      case 'in-progress':
        return AppTheme.statusSuccessText;
      case 'resolved':
      case 'solved':
        return Colors.blue;
      case 'closed':
        return AppTheme.statusInactiveText;
      default:
        return AppTheme.statusPendingText;
    }
  }

  String _getStatusText(BuildContext context, String status) {
    final s = _normalizeStatus(status);
    switch (s) {
      case 'initiated':
        return S.of(context)!.disputeStatusInitiated;
      case 'in-progress':
        return S.of(context)!.disputeStatusInProgress;
      case 'resolved':
      case 'solved':
        return S.of(context)!.disputeStatusResolved;
      case 'closed':
        return S.of(context)!.disputeStatusClosed;
      default:
        return S.of(context)!.disputeStatusInitiated;
    }
  }
}
