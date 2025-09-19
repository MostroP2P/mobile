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

  return disputes.map((dispute) {
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

    // If we found matching order state, use it for context
    if (matchingSession != null && matchingOrderState != null) {
      return DisputeData.fromDispute(dispute, orderState: matchingOrderState);
    }

    // Fallback: create DisputeData without order context
    return DisputeData.fromDispute(dispute);
  }).toList();
});