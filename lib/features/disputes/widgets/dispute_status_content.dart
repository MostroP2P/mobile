import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/dispute.dart';

class DisputeStatusContent extends StatelessWidget {
  final DisputeData dispute;

  const DisputeStatusContent({
    super.key,
    required this.dispute,
  });

  @override
  Widget build(BuildContext context) {
    bool isResolved = dispute.status.toLowerCase() == 'resolved' || dispute.status.toLowerCase() == 'closed';
    
    if (isResolved) {
      // Show resolution message for resolved/completed disputes
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.mostroGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.mostroGreen.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AppTheme.mostroGreen,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dispute Resolved',
                    style: TextStyle(
                      color: AppTheme.mostroGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This dispute has been resolved. The solver made a decision based on the evidence presented. Check your wallet for any refunds or payments.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Show instructions for in-progress disputes
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dispute.isCreator 
              ? 'You opened this dispute against the buyer ${dispute.counterparty}, please read carefully below:'
              : 'This dispute was opened against you by ${dispute.counterparty}, please read carefully below:',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildBulletPoint('Wait for a solver to take your dispute. Once they arrive, share any relevant evidence to help clarify the situation.'),
          _buildBulletPoint('The final decision will be made based on the evidence presented.'),
          _buildBulletPoint('If you don\'t respond, the system will assume you don\'t want to cooperate and you might lose the dispute.'),
          _buildBulletPoint('If you want to share your chat history with ${dispute.counterparty}, you can give the solver the shared key found in User Info in your conversation with that user.'),
        ],
      );
    }
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
