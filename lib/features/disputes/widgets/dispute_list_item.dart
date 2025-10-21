import 'package:flutter/material.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_icon.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_content.dart';
import 'package:mostro_mobile/services/dispute_read_status_service.dart';
import 'package:mostro_mobile/data/models/dispute.dart';

class DisputeListItem extends StatelessWidget {
  final DisputeData dispute;
  final VoidCallback onTap;

  const DisputeListItem({
    super.key,
    required this.dispute,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        // Mark dispute as read when user opens it
        await DisputeReadStatusService.markDisputeAsRead(dispute.disputeId);
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.05),
              width: 1.0,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DisputeIcon(),
              const SizedBox(width: 16),
              Expanded(
                child: DisputeContent(dispute: dispute),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
