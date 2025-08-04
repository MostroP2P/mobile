import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
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
  
  // Initialize the notifier with proper error handling and safety checks
  _initializeChatRoomSafely(ref, notifier, chatId);
  
  return notifier;
});

// Provider to track initialization status of chat rooms
final chatRoomInitializedProvider = StateProvider.family<bool, String>((ref, chatId) => false);

// Logger instance for the chat room provider
final _logger = Logger();

/// Safely initialize a chat room with proper error handling and context safety
Future<void> _initializeChatRoomSafely(
  Ref ref,
  ChatRoomNotifier notifier,
  String chatId,
) async {
  try {
    // Initialize the notifier
    await notifier.initialize();
    
    // Check if the provider is still mounted before updating state
    // This prevents state updates on disposed objects
    if (ref.container.read(chatRoomsProvider(chatId).notifier).mounted) {
      // Mark as initialized only if the provider is still active
      ref.read(chatRoomInitializedProvider(chatId).notifier).state = true;
      _logger.d('Chat room $chatId initialized successfully');
    } else {
      _logger.w('Chat room $chatId provider was disposed during initialization');
    }
  } catch (e, stackTrace) {
    // Use proper logging instead of print
    _logger.e(
      'Error initializing chat room $chatId: $e',
      error: e,
      stackTrace: stackTrace,
    );
    
    // Only update error state if provider is still mounted
    if (ref.container.read(chatRoomsProvider(chatId).notifier).mounted) {
      // Keep initialization status as false on error
      ref.read(chatRoomInitializedProvider(chatId).notifier).state = false;
    }
  }
}
