import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/features/chat/notifiers/chat_room_notifier.dart';
import 'package:mostro_mobile/features/chat/notifiers/chat_rooms_notifier.dart';

final chatRoomsNotifierProvider =
    StateNotifierProvider<ChatRoomsNotifier, List<ChatRoom>>(
  (ref) {
    return ChatRoomsNotifier(ref);
  },
);

// Provider to track initialization status of chat rooms
final chatRoomInitializedProvider = StateProvider.family<bool, String>((ref, chatId) => false);

// The main chat room provider with proper initialization handling
final chatRoomsProvider =
    StateNotifierProvider.family<ChatRoomNotifier, ChatRoom, String>(
        (ref, chatId) {
  final notifier = ChatRoomNotifier(
    ChatRoom(
      orderId: chatId,
      messages: [],
    ),
    chatId,
    ref,
  );
  
  // Initialize the notifier asynchronously and update the initialization status
  Future<void> initializeNotifier() async {
    try {
      await notifier.initialize();
      // Mark as initialized when complete
      ref.read(chatRoomInitializedProvider(chatId).notifier).state = true;
    } catch (e) {
      // Handle initialization errors
      // We don't rethrow as this is running in a fire-and-forget context
      // The error will be available in the notifier's state if needed
    }
  }
  
  // Start initialization but don't block provider creation
  initializeNotifier();
  
  return notifier;
});

// Helper provider to check if a chat room is ready for use
final isChatRoomReadyProvider = Provider.family<bool, String>((ref, chatId) {
  return ref.watch(chatRoomInitializedProvider(chatId));
});

