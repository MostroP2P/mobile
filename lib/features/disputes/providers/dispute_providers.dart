import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/models/dispute_chat.dart';
import 'package:mostro_mobile/features/disputes/notifiers/dispute_chat_notifier.dart';
import 'package:mostro_mobile/features/disputes/data/dispute_mock_data.dart';

/// Provider for dispute details - uses mock data when enabled
final disputeDetailsProvider = FutureProvider.family<Dispute?, String>((ref, disputeId) async {
  // Simulate loading time
  await Future.delayed(const Duration(milliseconds: 300));
  
  if (!DisputeMockData.isMockEnabled) {
    // TODO: Implement real dispute loading here
    return null;
  }
  
  // Get mock dispute data
  final disputeData = DisputeMockData.getDisputeById(disputeId);
  if (disputeData == null) return null;
  
  return Dispute(
    disputeId: disputeData.disputeId,
    orderId: disputeData.orderId,
    status: disputeData.status,
    createdAt: disputeData.createdAt,
    action: _getActionFromStatus(disputeData.status, disputeData.userRole.name),
    adminPubkey: disputeData.status != 'initiated' ? 'admin_123' : null,
  );
});

/// Helper function to convert status to action
String _getActionFromStatus(String status, String initiatorRole) {
  switch (status) {
    case 'initiated':
      return 'dispute-initiated-by-you';
    case 'in-progress':
      return initiatorRole == 'buyer' ? 'dispute-initiated-by-you' : 'dispute-initiated-by-peer';
    case 'resolved':
      return 'dispute-resolved';
    default:
      return 'dispute-initiated-by-you';
  }
}

/// Stub provider for dispute chat messages - UI only implementation
final disputeChatProvider = StateNotifierProvider.family<DisputeChatNotifier, List<DisputeChat>, String>(
  (ref, disputeId) {
    return ref.watch(disputeChatNotifierProvider(disputeId).notifier);
  },
);

/// Provider for user disputes list - uses mock data when enabled
final userDisputesProvider = FutureProvider<List<Dispute>>((ref) async {
  // Simulate loading time
  await Future.delayed(const Duration(milliseconds: 500));
  
  if (!DisputeMockData.isMockEnabled) {
    // TODO: Implement real disputes loading here
    return [];
  }
  
  // Convert mock dispute data to Dispute objects
  return DisputeMockData.mockDisputes.map((disputeData) => Dispute(
    disputeId: disputeData.disputeId,
    orderId: disputeData.orderId,
    status: disputeData.status,
    createdAt: disputeData.createdAt,
    action: _getActionFromStatus(disputeData.status, disputeData.userRole.name),
    adminPubkey: disputeData.status != 'initiated' ? 'admin_123' : null,
  )).toList();
});