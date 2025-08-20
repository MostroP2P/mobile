import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_status_badge.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_status_content.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/shared/providers/legible_handle_provider.dart';

class DisputeInfoCard extends ConsumerWidget {
  final DisputeData dispute;

  const DisputeInfoCard({
    super.key,
    required this.dispute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolve counterparty pubkey to readable nym
    final counterpartyNym = dispute.counterparty != 'Unknown' 
        ? ref.watch(nickNameProvider(dispute.counterparty))
        : 'Unknown';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dark1,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Dispute with ${dispute.userIsBuyer ? 'Seller' : 'Buyer'}: $counterpartyNym',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
