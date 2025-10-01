import 'package:mostro_mobile/data/enums.dart' as enums;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/models/dispute_chat.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/dispute_repository.dart';
import 'package:mostro_mobile/features/disputes/notifiers/dispute_chat_notifier.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';

/// Provider for the dispute repository
final disputeRepositoryProvider = Provider.autoDispose<DisputeRepository>((ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final settings = ref.watch(settingsProvider);
  final mostroPubkey = settings.mostroPublicKey;
  
  return DisputeRepository(nostrService, mostroPubkey, ref);
});

/// Provider for dispute details - uses real data from repository
final disputeDetailsProvider = FutureProvider.family<Dispute?, String>((ref, disputeId) async {
  final repository = ref.watch(disputeRepositoryProvider);
  
  // Watch all sessions to invalidate when they change
  final sessions = ref.watch(sessionNotifierProvider);
  
  // First try to find the specific order that contains this dispute
  String? targetOrderId;
  for (final session in sessions) {
    if (session.orderId != null) {
      try {
        final orderState = ref.read(orderNotifierProvider(session.orderId!));
        if (orderState.dispute?.disputeId == disputeId) {
          targetOrderId = session.orderId;
          break;
        }
      } catch (e) {
        // Continue checking other sessions
      }
    }
  }
  
  // If we found the specific order, watch only that one for optimal performance
  if (targetOrderId != null) {
    ref.watch(orderNotifierProvider(targetOrderId));
  } else {
    // Fallback: watch all order states to ensure we catch the dispute when it appears
    for (final session in sessions) {
      if (session.orderId != null) {
        try {
          ref.watch(orderNotifierProvider(session.orderId!));
        } catch (e) {
          // Continue if order state doesn't exist yet
        }
      }
    }
  }
  
  return repository.getDispute(disputeId);
});


/// Stub provider for dispute chat messages - UI only implementation
final disputeChatProvider = StateNotifierProvider.family<DisputeChatNotifier, List<DisputeChat>, String>(
  (ref, disputeId) {
    return ref.watch(disputeChatNotifierProvider(disputeId).notifier);
  },
);

/// Provider for user disputes list - uses real data from repository
final userDisputesProvider = FutureProvider<List<Dispute>>((ref) async {
  final repository = ref.watch(disputeRepositoryProvider);

  
  // Watch all sessions to invalidate when order states change
  final sessions = ref.watch(sessionNotifierProvider);
  
  // Watch order states for all sessions to trigger refresh when disputes update
  for (final session in sessions) {
    if (session.orderId != null) {
      try {
        ref.watch(orderNotifierProvider(session.orderId!));
      } catch (e) {
        // Continue if order state doesn't exist yet
      }
    }
  }
  

  return repository.getUserDisputes();
});

/// Provider for user disputes as DisputeData (UI view models)
final userDisputeDataProvider = FutureProvider<List<DisputeData>>((ref) async {
  final disputes = await ref.watch(userDisputesProvider.future);
  final sessions = ref.read(sessionNotifierProvider);

  final disputeDataList = disputes.map((dispute) {
    // Find the specific session for this dispute's order
    Session? matchingSession;
    dynamic matchingOrderState;

    // Try to find the session and order state that contains this dispute
    for (final session in sessions) {
      if (session.orderId != null) {
        try {
          final orderState = ref.read(orderNotifierProvider(session.orderId!));

          // Check if this order state contains our dispute
          if (orderState.dispute?.disputeId == dispute.disputeId) {
            matchingSession = session;
            matchingOrderState = orderState;
            break;
          }
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
      print('DisputeProvider: For dispute ${dispute.disputeId}, session.role = ${matchingSession.role}, converted to userRole = $userRole');
    } else {
      print('DisputeProvider: No session role found for dispute ${dispute.disputeId}');
    }

    // If we found matching order state, use it for context
    if (matchingSession != null && matchingOrderState != null) {
      return DisputeData.fromDispute(
        dispute, 
        orderState: matchingOrderState,
        userRole: userRole,
      );
    }

    // Fallback: create DisputeData without order context
    return DisputeData.fromDispute(
      dispute,
      userRole: userRole,
    );
  }).toList();

  // Sort disputes by creation date - most recent first
  disputeDataList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  
  return disputeDataList;
});