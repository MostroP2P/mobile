import 'package:flutter/material.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_communication_section.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_message_input.dart';
import 'package:mostro_mobile/features/disputes/data/dispute_mock_data.dart';
import 'package:mostro_mobile/core/app_theme.dart';

class DisputeChatScreen extends StatelessWidget {
  final String disputeId;

  const DisputeChatScreen({
    super.key,
    required this.disputeId,
  });

  @override
  Widget build(BuildContext context) {
    // Get dispute data from mock file
    final mockDispute = DisputeMockData.isMockEnabled 
        ? DisputeMockData.getDisputeById(disputeId)
        : null;
    
    // Fallback if no mock data found
    if (mockDispute == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dispute Chat'),
          backgroundColor: AppTheme.backgroundDark,
        ),
        backgroundColor: AppTheme.backgroundDark,
        body: const Center(
          child: Text(
            'Dispute not found',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

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
