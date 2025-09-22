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
    print('DEBUG: DisputeChatScreen.build() called with disputeId: $disputeId');
    
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
            
            // Try to get better peer information from order state
            print('DEBUG: OrderState peer: ${orderState.peer?.publicKey}');
            print('DEBUG: Order kind: ${orderState.order?.kind.value}');
            
            // If we have peer information in order state, use it for better dispute data
            if (orderState.peer != null) {
              print('DEBUG: Using peer pubkey from orderState: ${orderState.peer!.publicKey}');
              
              // Create DisputeData with enhanced peer information
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
          } catch (e) {
            // Continue checking other sessions
            continue;
          }
        }
      }
      
      // If we didn't find a matching order state, try to find any session with the same orderId
      // This helps when the dispute exists but the order state doesn't have the dispute yet
      for (final session in sessions) {
        if (session.orderId == dispute.orderId) {
          try {
            final orderState = ref.read(orderNotifierProvider(session.orderId!));
            // Use this order state even if it doesn't contain the dispute
            // This will help get the correct orderId and peer information
            return DisputeData.fromDispute(dispute, orderState: orderState);
          } catch (e) {
            // Continue checking other sessions
            continue;
          }
        }
      }
    } catch (e) {
      // Fallback to basic conversion
    }
    
    // Fallback: create DisputeData without order context
    return DisputeData.fromDispute(dispute);
  }
  
  /// Create DisputeData with enhanced peer information from chat
  DisputeData _createDisputeDataWithChatInfo(
    Dispute dispute, 
    dynamic orderState, 
    String peerPubkey
  ) {
    // Create a custom DisputeData with the correct peer information
    final order = orderState.order;
    
    print('DEBUG: Creating DisputeData with chat info');
    print('DEBUG: Order kind: ${order?.kind.value}');
    print('DEBUG: Peer pubkey: $peerPubkey');
    
    // Determine user role based on order type and who initiated the dispute
    UserRole userRole = UserRole.unknown;
    if (order != null) {
      // Check if user initiated the dispute to infer their role
      bool? isUserCreator;
      if (orderState.action != null) {
        isUserCreator = orderState.action.toString() == 'dispute-initiated-by-you';
        print('DEBUG: orderState.action: ${orderState.action}');
        print('DEBUG: isUserCreator: $isUserCreator');
      }
      
      // For now, let's assume the simpler logic:
      // In a 'buy' order, the user is the buyer (creator of buy order)
      // In a 'sell' order, the user is the seller (creator of sell order)
      // This is the most straightforward interpretation
      userRole = order.kind.value == 'buy' ? UserRole.buyer : UserRole.seller;
      print('DEBUG: Order kind: ${order.kind.value} -> User role: $userRole');
    }
    
    final disputeData = DisputeData(
      disputeId: dispute.disputeId,
      orderId: dispute.orderId ?? order?.id,
      status: dispute.status ?? 'initiated',
      descriptionKey: DisputeDescriptionKey.initiatedByUser, // Assuming user created the dispute
      counterparty: peerPubkey, // Use the peer pubkey from chat
      isCreator: true, // Assuming user created the dispute for now
      createdAt: dispute.createdAt ?? DateTime.now(),
      userRole: userRole,
      action: dispute.action,
    );
    
    print('DEBUG: Created DisputeData - userIsBuyer: ${disputeData.userIsBuyer}');
    print('DEBUG: Created DisputeData - counterparty: ${disputeData.counterpartyDisplay}');
    
    return disputeData;
  }
}
