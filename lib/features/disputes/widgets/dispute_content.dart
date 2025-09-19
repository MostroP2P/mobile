import 'package:flutter/material.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_header.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_order_id.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_description.dart';
import 'package:mostro_mobile/data/models/dispute.dart';

/// Main content widget for dispute information
class DisputeContent extends StatelessWidget {
  final DisputeData dispute;

  const DisputeContent({super.key, required this.dispute});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DisputeHeader(dispute: dispute),
        const SizedBox(height: 4),
        DisputeOrderId(orderId: dispute.orderIdDisplay),
        const SizedBox(height: 2),
        DisputeDescription(description: dispute.getLocalizedDescription(context)),
      ],
    );
  }
}
