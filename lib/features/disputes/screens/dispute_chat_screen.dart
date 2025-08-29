import 'package:flutter/material.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_info_card.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_communication_section.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_input_section.dart';
import 'package:mostro_mobile/core/app_theme.dart';

class DisputeChatScreen extends StatelessWidget {
  final String disputeId;

  const DisputeChatScreen({
    super.key,
    required this.disputeId,
  });

  @override
  Widget build(BuildContext context) {
    // Mock dispute data for UI demonstration - vary based on disputeId
    final isResolvedDispute = disputeId == 'dispute_003';
    final mockDispute = DisputeData(
      disputeId: disputeId,
      orderId: 'order_${disputeId.substring(0, 8)}',
      status: isResolvedDispute ? 'resolved' : 'in-progress',
      descriptionKey: isResolvedDispute ? DisputeDescriptionKey.resolved : DisputeDescriptionKey.inProgress,
      counterparty: 'admin_123',
      isCreator: true,
      createdAt: DateTime.now().subtract(Duration(hours: isResolvedDispute ? 72 : 2)),
      userRole: UserRole.buyer,
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        title: Text(
          'Dispute Chat',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Dispute info card
          DisputeInfoCard(dispute: mockDispute),
          
          // Communication section with mock messages
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  DisputeCommunicationSection(
                    disputeId: disputeId,
                    status: mockDispute.status,
                  ),
                ],
              ),
            ),
          ),
          
          // Input section for sending messages (only show if not resolved)
          if (mockDispute.status != 'resolved')
            DisputeInputSection(disputeId: disputeId),
        ],
      ),
    );
  }
}
