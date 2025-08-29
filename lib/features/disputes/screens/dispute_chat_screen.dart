import 'package:flutter/material.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_communication_section.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_message_input.dart';
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
    String status;
    DisputeDescriptionKey descriptionKey;
    int hoursAgo;
    
    switch (disputeId) {
      case 'dispute_001':
        status = 'initiated';
        descriptionKey = DisputeDescriptionKey.initiatedByUser;
        hoursAgo = 2;
        break;
      case 'dispute_002':
        status = 'in-progress';
        descriptionKey = DisputeDescriptionKey.inProgress;
        hoursAgo = 24;
        break;
      case 'dispute_003':
        status = 'resolved';
        descriptionKey = DisputeDescriptionKey.resolved;
        hoursAgo = 72;
        break;
      default:
        status = 'in-progress';
        descriptionKey = DisputeDescriptionKey.inProgress;
        hoursAgo = 2;
        break;
    }
    
    final mockDispute = DisputeData(
      disputeId: disputeId,
      orderId: 'order_${disputeId.substring(0, 8)}',
      status: status,
      descriptionKey: descriptionKey,
      counterparty: status == 'initiated' ? null : 'admin_123',
      isCreator: true,
      createdAt: DateTime.now().subtract(Duration(hours: hoursAgo)),
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
          // Communication section with messages (includes info card in scroll)
          DisputeCommunicationSection(
            disputeId: disputeId,
            disputeData: mockDispute,
            status: mockDispute.status,
          ),
          
          // Input section for sending messages (only show if not resolved and not initiated)
          if (mockDispute.status != 'resolved' && mockDispute.status != 'initiated')
            DisputeMessageInput(disputeId: disputeId),
        ],
      ),
    );
  }
}
