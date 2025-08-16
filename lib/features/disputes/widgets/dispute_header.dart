import 'package:flutter/material.dart';
import 'package:mostro_mobile/features/disputes/widgets/disputes_list.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_status_badge.dart';

/// Header widget with title and status badge for dispute list items
class DisputeHeader extends StatelessWidget {
  final DisputeData dispute;

  const DisputeHeader({super.key, required this.dispute});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Dispute for order',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        DisputeStatusBadge(status: dispute.status),
      ],
    );
  }
}
