import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/models/dispute_chat.dart';
import 'package:mostro_mobile/features/disputes/notifiers/dispute_chat_notifier.dart';

/// Stub provider for dispute details - UI only implementation
final disputeDetailsProvider = FutureProvider.family<Dispute?, String>((ref, disputeId) async {
  // Simulate loading time
  await Future.delayed(const Duration(milliseconds: 300));
  
  // Return a mock dispute for UI testing
  return Dispute(
    disputeId: disputeId,
    orderId: 'order_${disputeId.substring(0, 8)}',
    status: 'initiated',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    action: 'dispute-initiated-by-you',
    adminPubkey: null,
  );
});

/// Stub provider for dispute chat messages - UI only implementation
final disputeChatProvider = StateNotifierProvider.family<DisputeChatNotifier, List<DisputeChat>, String>(
  (ref, disputeId) {
    return ref.watch(disputeChatNotifierProvider(disputeId).notifier);
  },
);

/// Stub provider for user disputes list - UI only implementation  
final userDisputesProvider = FutureProvider<List<Dispute>>((ref) async {
  // Simulate loading time
  await Future.delayed(const Duration(milliseconds: 500));
  
  // Return mock disputes for UI testing
  return [
    Dispute(
      disputeId: 'dispute_001',
      orderId: 'order_001',
      status: 'initiated',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      action: 'dispute-initiated-by-you',
    ),
    Dispute(
      disputeId: 'dispute_002',
      orderId: 'order_002',
      status: 'in-progress',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      action: 'dispute-initiated-by-peer',
      adminPubkey: 'admin_123',
    ),
    Dispute(
      disputeId: 'dispute_003',
      orderId: 'order_003',
      status: 'resolved',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      action: 'dispute-resolved',
    ),
  ];
});