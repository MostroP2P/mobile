import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/features/chat/notifiers/chat_rooms_notifier.dart';
import 'package:mostro_mobile/features/chat/chat_room_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';

// Re-export providers from chat_room_provider.dart
export 'package:mostro_mobile/features/chat/chat_room_provider.dart';

final chatRoomsNotifierProvider =
    StateNotifierProvider<ChatRoomsNotifier, List<ChatRoom>>(
  (ref) {
    return ChatRoomsNotifier(ref);
  },
);



// Helper provider to check if a chat room is ready for use
final isChatRoomReadyProvider = Provider.family<bool, String>((ref, chatId) {
  return ref.watch(chatRoomInitializedProvider(chatId));
});

// Optimized provider that returns sorted chat rooms with fresh data
// This prevents excessive rebuilds by memoizing the sorted list
final sortedChatRoomsProvider = Provider<List<ChatRoom>>((ref) {
  // Watch the main chat rooms list
  final chatRoomsList = ref.watch(chatRoomsNotifierProvider);
  
  // Get fresh data for each chat room and sort them
  final chatRoomsWithFreshData = chatRoomsList.map((chatRoom) {
    // Watch individual chat providers to get the most up-to-date state
    return ref.watch(chatRoomsProvider(chatRoom.orderId));
  }).toList();
  
  // Sort by session start time (most recently taken order first)
  chatRoomsWithFreshData.sort((a, b) {
    final aSessionStartTime = _getSessionStartTime(ref, a);
    final bSessionStartTime = _getSessionStartTime(ref, b);
    return bSessionStartTime.compareTo(aSessionStartTime);
  });
  
  return chatRoomsWithFreshData;
});

// Helper function to get session start time for sorting with improved error handling
int _getSessionStartTime(Ref ref, ChatRoom chatRoom) {
  try {
    // Safely attempt to read the session with proper error handling
    final session = ref.read(sessionProvider(chatRoom.orderId));
    if (session != null) {
      // Return the session start time (when the order was taken/contacted)
      final startTime = session.startTime.millisecondsSinceEpoch ~/ 1000;
      logger.d('Retrieved session start time for chat ${chatRoom.orderId}: $startTime');
      return startTime;
    } else {
      logger.i('No session found for chat ${chatRoom.orderId}, using fallback time');
    }
  } catch (e, stackTrace) {
    // Enhanced error handling with proper logging for diagnostics
    logger.e(
      'Error getting session start time for chat ${chatRoom.orderId}: $e',
      error: e,
      stackTrace: stackTrace,
    );
  }

  // Fallback: use current time so new chats appear at top
  final fallbackTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  logger.d('Using fallback time for chat ${chatRoom.orderId}: $fallbackTime');
  return fallbackTime;
}
