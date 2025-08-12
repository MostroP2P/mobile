import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_status_badge.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_status_content.dart';
import 'package:mostro_mobile/data/models/dispute.dart';

class DisputeInfoCard extends StatelessWidget {
  final DisputeData dispute;

  const DisputeInfoCard({
    super.key,
    required this.dispute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dark1, // Same background as My Active Trades items
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with warning icon and title
          Row(
            children: [
              Icon(
                Icons.warning_amber,
                color: Colors.amber,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Dispute with ${dispute.isCreator ? 'Buyer' : 'Seller'}: ${dispute.counterparty}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Status badge - reuse the component for consistency
              DisputeStatusBadge(status: dispute.status),
            ],
          ),
          const SizedBox(height: 16),
          
          // Order ID
          _buildInfoRow('Order ID', dispute.orderId),
          const SizedBox(height: 8),
          
          // Dispute ID
          _buildInfoRow('Dispute ID', dispute.disputeId),
          const SizedBox(height: 16),
          
          // Dispute description - conditional based on status
          DisputeStatusContent(dispute: dispute),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
