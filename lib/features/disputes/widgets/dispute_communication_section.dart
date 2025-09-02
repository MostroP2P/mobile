import 'package:flutter/material.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_messages_list.dart';
import 'package:mostro_mobile/data/models/dispute.dart';

class DisputeCommunicationSection extends StatelessWidget {
  final String disputeId;
  final String status;
  final DisputeData disputeData;

  const DisputeCommunicationSection({
    super.key,
    required this.disputeId,
    required this.disputeData,
    this.status = 'in-progress',
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DisputeMessagesList(
        disputeId: disputeId,
        status: status,
        disputeData: disputeData, // Pass dispute data to include in scroll
      ),
    );
  }
}