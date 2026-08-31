import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/chat_read_status_service.dart';
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
  
  // Sort by session start time (most recently taken order first). Keys are
  // computed once per room: the comparator used to call ref.read and log on
  // every comparison (O(n log n) per rebuild), and its per-comparison
  // DateTime.now() fallback made the ordering unstable.
  final fallbackTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final startTimes = <String, int>{
    for (final room in chatRoomsWithFreshData)
      room.orderId: _getSessionStartTime(ref, room, fallbackTime),
  };
  chatRoomsWithFreshData.sort(
    (a, b) => startTimes[b.orderId]!.compareTo(startTimes[a.orderId]!),
  );

  return chatRoomsWithFreshData;
});

// Logger instance for session start time operations


// Session start time for sorting; [fallbackTime] keeps rooms without a
// session at the top with a stable key.
int _getSessionStartTime(Ref ref, ChatRoom chatRoom, int fallbackTime) {
  try {
    final session = ref.read(sessionProvider(chatRoom.orderId));
    if (session != null) {
      return session.startTime.millisecondsSinceEpoch ~/ 1000;
    }
  } catch (e, stackTrace) {
    logger.e(
      'Error getting session start time for chat ${chatRoom.orderId}: $e',
      error: e,
      stackTrace: stackTrace,
    );
  }
  return fallbackTime;
}

/// Whether the chat for [orderId] has peer messages newer than the read
/// cursor. Replaces a per-row FutureBuilder whose future (a prefs read) was
/// recreated on every rebuild; this recomputes only when the room changes.
/// Invalidate it after `ChatReadStatusService.markChatAsRead`.
final chatHasUnreadProvider =
    FutureProvider.family<bool, String>((ref, orderId) async {
  final session = ref.watch(sessionProvider(orderId));
  if (session == null) return false;
  final room = ref.watch(chatRoomsProvider(orderId));
  if (room.messages.isEmpty) return false;
  return ChatReadStatusService.hasUnreadMessages(
    orderId,
    room.messages,
    session.tradeKey.public,
  );
});
