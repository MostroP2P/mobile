import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_communication_section.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_message_input.dart';
import 'package:mostro_mobile/features/disputes/providers/dispute_providers.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';

class DisputeChatScreen extends ConsumerWidget {
  final String disputeId;

  const DisputeChatScreen({
    super.key,
    required this.disputeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get real dispute data from provider
    final disputeAsync = ref.watch(disputeDetailsProvider(disputeId));
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        title: const Text(
          'Dispute Chat',
          style: TextStyle(
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
      body: disputeAsync.when(
        data: (dispute) {
          if (dispute == null) {
            return const Center(
              child: Text(
                'Dispute not found',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          
          // Convert Dispute to DisputeData for UI
          final disputeData = _convertToDisputeData(dispute, ref);
          
          return Column(
            children: [
              // Communication section with messages (includes info card in scroll)
              DisputeCommunicationSection(
                disputeId: disputeId,
                disputeData: disputeData,
                status: disputeData.status,
              ),
              
              // Input section for sending messages (only show if not resolved and not initiated)
              if (disputeData.status != 'resolved' && disputeData.status != 'initiated')
                DisputeMessageInput(disputeId: disputeId),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: Colors.green,
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Error loading dispute',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                error.toString(),
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Convert Dispute model to DisputeData for UI consumption
  DisputeData _convertToDisputeData(Dispute dispute, WidgetRef ref) {
    // Try to get order state context for better data
    try {
      final sessions = ref.read(sessionNotifierProvider);

      // Find the session that matches this dispute's order
      for (final session in sessions) {
        if (session.orderId == dispute.orderId) {
          try {
            final orderState = ref.read(orderNotifierProvider(session.orderId!));

            // Always prioritize session.peer information when available
            // This ensures consistent peer information across all dispute states
            if (session.peer != null) {
              // Create DisputeData with enhanced peer information from session
              return _createDisputeDataWithChatInfo(
                dispute,
                orderState,
                session.peer!.publicKey // Use session.peer for correct counterparty
              );
            }

            // If no session.peer but orderState.peer exists, use that
            if (orderState.peer != null) {
              return _createDisputeDataWithChatInfo(
                dispute,
                orderState,
                orderState.peer!.publicKey
              );
            }

            // If this order state contains our dispute, use it for context
            if (orderState.dispute?.disputeId == dispute.disputeId) {
              return DisputeData.fromDispute(dispute, orderState: orderState);
            }

            // Use order state even if it doesn't contain the dispute yet
            return DisputeData.fromDispute(dispute, orderState: orderState);
          } catch (e) {
            // Continue checking other sessions
            continue;
          }
        }
      }

      // If we didn't find exact match, try to find any session with peer info
      // This is a fallback to ensure we get peer information when possible
      for (final session in sessions) {
        if (session.peer != null) {
          try {
            final orderState = ref.read(orderNotifierProvider(session.orderId!));
            // Use this session's peer info as fallback
            return _createDisputeDataWithChatInfo(
              dispute,
              orderState,
              session.peer!.publicKey
            );
          } catch (e) {
            // Continue checking other sessions
            continue;
          }
        }
      }
    } catch (e) {
      // Fallback to basic conversion
    }

    return DisputeData.fromDispute(dispute);
  }
  
  /// Create DisputeData with enhanced peer information from chat
  DisputeData _createDisputeDataWithChatInfo(
    Dispute dispute, 
    dynamic orderState, 
    String peerPubkey
  ) {
    // Use the same logic as DisputeData.fromDispute but with custom peer information
    // This ensures consistency across all dispute states
    
    // First, create the dispute data using the standard method
    final standardDisputeData = DisputeData.fromDispute(dispute, orderState: orderState);
    
    // Then override the counterparty with the correct peer information
    final disputeData = DisputeData(
      disputeId: standardDisputeData.disputeId,
      orderId: standardDisputeData.orderId,
      status: standardDisputeData.status,
      descriptionKey: standardDisputeData.descriptionKey,
      counterparty: peerPubkey, // Use the peer pubkey from session/chat
      isCreator: standardDisputeData.isCreator,
      createdAt: standardDisputeData.createdAt,
      userRole: standardDisputeData.userRole,
      action: standardDisputeData.action,
    );
    
    return disputeData;
  }
}
