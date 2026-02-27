import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/shared/providers/legible_handle_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class DisputeStatusContent extends ConsumerWidget {
  final DisputeData dispute;

  const DisputeStatusContent({
    super.key,
    required this.dispute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolve counterparty pubkey to readable nym
    final hasCounterparty = dispute.counterpartyDisplay != DisputeSemanticKeys.unknownCounterparty && 
                            dispute.counterpartyDisplay.trim().isNotEmpty;
    final counterpartyNym = hasCounterparty
        ? ref.watch(nickNameProvider(dispute.counterpartyDisplay))
        : S.of(context)!.unknown;
    
    // Check if dispute is in a resolved/closed state
    final status = dispute.status.toLowerCase();
    bool isResolved = status == 'resolved' || status == 'closed' || status == 'seller-refunded';
    
    if (isResolved) {
      // Show resolution message for resolved/completed disputes
      // Get the appropriate message based on the resolution type and user role
      String message;
      
      // Debug logging to track action and user role
      debugPrint('DisputeStatusContent: status=$status, action=${dispute.action}, userRole=${dispute.userRole}');
      
      // Check action first to determine the type of resolution
      if (dispute.action == 'admin-canceled' || status == 'seller-refunded') {
        // Admin canceled the order and refunded the seller
        // This means the buyer doesn't get the sats, seller gets refunded
        if (dispute.userRole == UserRole.buyer) {
          message = S.of(context)!.disputeCanceledBuyerMessage;
        } else if (dispute.userRole == UserRole.seller) {
          message = S.of(context)!.disputeCanceledSellerMessage;
        } else {
          message = S.of(context)!.disputeSellerRefundedMessage;
        }
      } else if (dispute.action == 'admin-settled') {
        // Admin settled in favor of one party - order completed successfully
        // The buyer receives the sats, seller gets paid
        if (dispute.userRole == UserRole.buyer) {
          message = S.of(context)!.disputeSettledBuyerMessage;
        } else if (dispute.userRole == UserRole.seller) {
          message = S.of(context)!.disputeSettledSellerMessage;
        } else {
          message = S.of(context)!.disputeAdminSettledMessage;
        }
      } else if (dispute.action == 'user-completed') {
        // Order was completed by the users themselves (seller released sats)
        message = S.of(context)!.disputeClosedUserCompleted;
      } else if (dispute.action == 'cooperative-cancel') {
        // Order was cooperatively canceled by the parties
        message = S.of(context)!.disputeClosedCooperativeCancel;
      } else {
        // Fallback for generic resolved status without specific action
        message = S.of(context)!.disputeResolvedMessage;
      }
      
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
                    message,
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
            _getDisputeStatusText(context, counterpartyNym),
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
          _buildBulletPoint(S.of(context)!.disputeInstruction4(counterpartyNym)),
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
  String _getDisputeStatusText(BuildContext context, String counterpartyNym) {
    switch (dispute.descriptionKey) {
      case DisputeDescriptionKey.initiatedByUser:
        // Use the appropriate message based on user role
        if (dispute.userRole == UserRole.buyer) {
          // User is buyer, so dispute is against seller
          return S.of(context)!.disputeOpenedByYouAgainstSeller(counterpartyNym);
        } else if (dispute.userRole == UserRole.seller) {
          // User is seller, so dispute is against buyer
          return S.of(context)!.disputeOpenedByYouAgainstBuyer(counterpartyNym);
        } else {
          // Unknown role, use generic message
          return S.of(context)!.disputeOpenedByYou(counterpartyNym);
        }
      case DisputeDescriptionKey.initiatedByPeer:
        return S.of(context)!.disputeOpenedAgainstYou(counterpartyNym);
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
