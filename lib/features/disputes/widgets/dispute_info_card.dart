import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_status_badge.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_status_content.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/shared/providers/legible_handle_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class DisputeInfoCard extends ConsumerWidget {
  final DisputeData dispute;

  const DisputeInfoCard({
    super.key,
    required this.dispute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolve counterparty pubkey to readable nym
    final counterpartyNym = dispute.counterparty != S.of(context)!.unknown 
        ? ref.watch(nickNameProvider(dispute.counterparty))
        : S.of(context)!.unknown;
    
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
                  S.of(context)!.disputeWith(
                    dispute.userIsBuyer ? S.of(context)!.seller : S.of(context)!.buyer,
                    counterpartyNym,
                  ),
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
          _buildInfoRow(context, S.of(context)!.orderIdLabel, dispute.orderId),
          const SizedBox(height: 8),
          
          // Dispute ID
          _buildInfoRow(context, S.of(context)!.disputeIdLabel, dispute.disputeId),
          const SizedBox(height: 16),
          
          // Dispute description - conditional based on status
          DisputeStatusContent(dispute: dispute),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
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
