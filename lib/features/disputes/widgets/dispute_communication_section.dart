import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class DisputeCommunicationSection extends StatelessWidget {
  final String disputeId;
  final String status;

  const DisputeCommunicationSection({
    super.key,
    required this.disputeId,
    this.status = 'in-progress',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)?.disputeCommunication ?? 'Communication',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          _buildSimpleCommunication(context),
        ],
      ),
    );
  }

  Widget _buildSimpleCommunication(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mock admin assignment message
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.blue[900],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  color: Colors.blue[300],
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.of(context)?.adminAssigned ?? 'Admin has been assigned to this dispute',
                    style: TextStyle(
                      color: Colors.blue[300],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Mock messages based on status
          if (status == 'resolved') ...[
            _buildMockMessage(
              'Hello, I need help with this order. The seller hasn\'t responded.',
              true,
              DateTime.now().subtract(const Duration(days: 3, hours: 2)),
            ),
            const SizedBox(height: 8),
            _buildMockMessage(
              'I understand your concern. Let me review the order details and contact the seller.',
              false,
              DateTime.now().subtract(const Duration(days: 3, hours: 1)),
            ),
            const SizedBox(height: 8),
            _buildMockMessage(
              'I\'ve contacted the seller and they will complete the payment now.',
              false,
              DateTime.now().subtract(const Duration(days: 2, hours: 12)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green[300],
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dispute resolved - Payment completed successfully',
                      style: TextStyle(
                        color: Colors.green[300],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            _buildMockMessage(
              'Hello, I need help with this order. The seller hasn\'t responded.',
              true,
              DateTime.now().subtract(const Duration(hours: 2)),
            ),
            const SizedBox(height: 8),
            _buildMockMessage(
              'I understand your concern. Let me review the order details and contact the seller.',
              false,
              DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
            ),
            const SizedBox(height: 8),
            _buildMockMessage(
              'Thank you for your patience. I\'m working on resolving this issue.',
              false,
              DateTime.now().subtract(const Duration(minutes: 30)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMockMessage(String text, bool isFromUser, DateTime timestamp) {
    return Align(
      alignment: isFromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isFromUser ? Colors.blue[700] : Colors.grey[700],
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(timestamp),
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}