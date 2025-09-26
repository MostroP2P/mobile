import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/generated/l10n.dart';

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
                    S.of(context)!.disputeResolvedTitle,
                    style: TextStyle(
                      color: AppTheme.mostroGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    S.of(context)!.disputeResolvedMessage,
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
            _getDisputeStatusText(context),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildBulletPoint(S.of(context)!.disputeInstruction1),
          _buildBulletPoint(S.of(context)!.disputeInstruction2),
          _buildBulletPoint(S.of(context)!.disputeInstruction3),
          _buildBulletPoint(S.of(context)!.disputeInstruction4(dispute.counterpartyDisplay)),
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
  
  /// Get the appropriate localized text based on the dispute description key
  String _getDisputeStatusText(BuildContext context) {
    switch (dispute.descriptionKey) {
      case DisputeDescriptionKey.initiatedByUser:
        // Use the appropriate message based on whether user is buyer or seller
        if (dispute.userIsBuyer) {
          // User is buyer, so dispute is against seller
          return S.of(context)!.disputeOpenedByYouAgainstSeller(dispute.counterpartyDisplay);
        } else {
          // User is seller, so dispute is against buyer
          return S.of(context)!.disputeOpenedByYouAgainstBuyer(dispute.counterpartyDisplay);
        }
      case DisputeDescriptionKey.initiatedByPeer:
        return S.of(context)!.disputeOpenedAgainstYou(dispute.counterpartyDisplay);
      case DisputeDescriptionKey.initiatedPendingAdmin:
        return S.of(context)!.disputeWaitingForAdmin;
      case DisputeDescriptionKey.inProgress:

        // For in-progress disputes, admin is already assigned, so show appropriate message
        // Instead of "No messages yet", show a message indicating the dispute is active
        return S.of(context)!.disputeInProgress;

      case DisputeDescriptionKey.resolved:
        // Show specific resolution message based on action
        if (dispute.action == 'admin-settled') {
          return S.of(context)!.disputeAdminSettledMessage;
        }
        return S.of(context)!.disputeResolvedMessage;
      case DisputeDescriptionKey.sellerRefunded:
        return S.of(context)!.disputeSellerRefundedMessage;
      case DisputeDescriptionKey.unknown:
        // Use a generic message with the status
        return "${S.of(context)!.unknown} ${S.of(context)!.disputeStatusResolved}";
    }
  }
}
