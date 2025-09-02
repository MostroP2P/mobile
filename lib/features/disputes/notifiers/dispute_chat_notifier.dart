import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/dispute_chat.dart';

/// Stub notifier for DisputeChat - UI only implementation
class DisputeChatNotifier extends StateNotifier<List<DisputeChat>> {
  DisputeChatNotifier() : super([]);

  void sendMessage(String message) {
    // Stub implementation - just add a mock message
    final newMessage = DisputeChat(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      timestamp: DateTime.now(),
      isFromUser: true,
    );
    state = [...state, newMessage];
  }

  void loadMessages(String disputeId) {
    // Stub implementation - load mock messages
    state = [
      DisputeChat(
        id: '1',
        message: 'Hello, I have an issue with this order',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        isFromUser: true,
      ),
      DisputeChat(
        id: '2',
        message: 'I understand. Let me review the details.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
        isFromUser: false,
        adminPubkey: 'admin_pubkey_123',
      ),
    ];
  }
}

final disputeChatNotifierProvider =
    StateNotifierProvider.family<DisputeChatNotifier, List<DisputeChat>, String>(
  (ref, disputeId) {
    final notifier = DisputeChatNotifier();
    notifier.loadMessages(disputeId);
    return notifier;
  },
);