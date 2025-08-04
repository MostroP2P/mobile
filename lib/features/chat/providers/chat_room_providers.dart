import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/features/chat/notifiers/chat_rooms_notifier.dart';
import 'package:mostro_mobile/features/chat/chat_room_provider.dart';

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
