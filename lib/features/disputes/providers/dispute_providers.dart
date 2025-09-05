import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/models/dispute_chat.dart';
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
  return repository.getUserDisputes();
});

/// Provider for user disputes as DisputeData (UI view models)
final userDisputeDataProvider = FutureProvider<List<DisputeData>>((ref) async {
  final disputes = await ref.watch(userDisputesProvider.future);
  final sessions = ref.read(sessionNotifierProvider);
  
  return disputes.map((dispute) {
    // Find the session that contains this dispute to get OrderState context
    final session = sessions.firstWhereOrNull(
      (s) => s.orderId != null,
    );
    
    if (session?.orderId != null) {
      try {
        final orderState = ref.read(orderNotifierProvider(session!.orderId!));
        
        if (orderState.dispute?.disputeId == dispute.disputeId) {
          return DisputeData.fromDispute(dispute, orderState: orderState);
        }
      } catch (e) {
        // If we can't get the order state, create DisputeData without context
      }
    }
    
    return DisputeData.fromDispute(dispute);
  }).toList();
});