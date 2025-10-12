import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/enums.dart' as enums;
import 'package:mostro_mobile/features/disputes/widgets/dispute_communication_section.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_message_input.dart';
import 'package:mostro_mobile/features/disputes/providers/dispute_providers.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';

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
        title: Text(
          S.of(context)?.disputeDetails ?? 'Dispute Details',
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
      body: disputeAsync.when(
        data: (dispute) {
          if (dispute == null) {
            return Center(
              child: Text(
                S.of(context)?.disputeNotFound ?? 'Dispute not found',
                style: const TextStyle(color: Colors.white),
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

              // Input section for sending messages (only show if in-progress)
              if (disputeData.status == 'in-progress')
                DisputeMessageInput(disputeId: disputeId)
              // For 'initiated' and 'resolved' status, don't show input
              // Chat closed message is now shown within the messages area
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: Colors.green,
          ),
        ),
        error: (error, stack) => Center(
          child: Text(
            S.of(context)?.errorLoadingDispute(error.toString()) ?? 'Error loading dispute: ${error.toString()}',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
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
      Session? matchingSession;
      dynamic matchingOrderState;
      
      for (final session in sessions) {
        if (session.orderId != null && 
            dispute.orderId != null && 
            session.orderId == dispute.orderId) {
          try {
            final orderState = ref.read(orderNotifierProvider(session.orderId!));
            matchingSession = session;
            matchingOrderState = orderState;
            break;
          } catch (e) {
            // Continue checking other sessions
            continue;
          }
        }
      }

      // Convert session role to UserRole
      UserRole? userRole;
      if (matchingSession?.role != null) {
        userRole = matchingSession!.role == enums.Role.buyer 
            ? UserRole.buyer 
            : matchingSession.role == enums.Role.seller
                ? UserRole.seller
                : UserRole.unknown;
        debugPrint('DisputeChatScreen: session.role = ${matchingSession.role}, converted to userRole = $userRole');
      } else {
        debugPrint('DisputeChatScreen: No session role found for dispute ${dispute.disputeId}');
      }

      // If we found a matching session, use it
      if (matchingSession != null && matchingOrderState != null) {
        // Always prioritize session.peer information when available
        // This ensures consistent peer information across all dispute states
        if (matchingSession.peer != null) {
          // Create DisputeData with enhanced peer information from session
          return _createDisputeDataWithChatInfo(
            dispute,
            matchingOrderState,
            matchingSession.peer!.publicKey, // Use session.peer for correct counterparty
            userRole,
          );
        }

        // If no session.peer but orderState.peer exists, use that
        if (matchingOrderState.peer != null) {
          return _createDisputeDataWithChatInfo(
            dispute,
            matchingOrderState,
            matchingOrderState.peer!.publicKey,
            userRole,
          );
        }

        // Use order state for context even without peer info
        return DisputeData.fromDispute(
          dispute, 
          orderState: matchingOrderState,
          userRole: userRole,
        );
      }

      // If we didn't find exact match by orderId, try to find the dispute by disputeId
      // This is important for resolved disputes where the orderId might not match exactly
      for (final session in sessions) {
        if (session.orderId != null) {
          try {
            final orderState = ref.read(orderNotifierProvider(session.orderId!));
            
            // Check if this order state contains our dispute
            if (orderState.dispute?.disputeId == dispute.disputeId) {
              // Convert session role to UserRole
              UserRole? userRole;
              if (session.role != null) {
                userRole = session.role == enums.Role.buyer 
                    ? UserRole.buyer 
                    : session.role == enums.Role.seller
                        ? UserRole.seller
                        : UserRole.unknown;
                debugPrint('DisputeChatScreen (fallback): session.role = ${session.role}, converted to userRole = $userRole');
              } else {
                debugPrint('DisputeChatScreen (fallback): No session role found for dispute ${dispute.disputeId}');
              }
              
              // Found the order state that contains this dispute
              if (session.peer != null) {
                return _createDisputeDataWithChatInfo(
                  dispute,
                  orderState,
                  session.peer!.publicKey,
                  userRole,
                );
              }
              
              if (orderState.peer != null) {
                return _createDisputeDataWithChatInfo(
                  dispute,
                  orderState,
                  orderState.peer!.publicKey,
                  userRole,
                );
              }
              
              return DisputeData.fromDispute(
                dispute, 
                orderState: orderState,
                userRole: userRole,
              );
            }
          } catch (e) {
            // Continue checking other sessions
            continue;
          }
        }
      }

      // No matching session or order state found with peer info
      // Fall back to basic dispute conversion without peer context
    } catch (e) {
      // Fallback to basic conversion on error
    }

    return DisputeData.fromDispute(dispute);
  }
  
  /// Create DisputeData with enhanced peer information from chat
  DisputeData _createDisputeDataWithChatInfo(
    Dispute dispute, 
    dynamic orderState, 
    String peerPubkey,
    UserRole? userRole,
  ) {
    // Use the same logic as DisputeData.fromDispute but with custom peer information
    // This ensures consistency across all dispute states
    
    // First, create the dispute data using the standard method
    final standardDisputeData = DisputeData.fromDispute(
      dispute, 
      orderState: orderState,
      userRole: userRole,
    );
    
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
