import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/features/chat/notifiers/chat_room_notifier.dart';

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
      // Mark as initialized
      ref.read(chatRoomInitializedProvider(chatId).notifier).state = true;
    } catch (e) {
      // Handle initialization error
      print('Error initializing chat room $chatId: $e');
    }
  }
  
  // Start initialization but don't block provider creation
  initializeNotifier();
  
  return notifier;
});

// Provider to track initialization status of chat rooms
final chatRoomInitializedProvider = StateProvider.family<bool, String>((ref, chatId) => false);
