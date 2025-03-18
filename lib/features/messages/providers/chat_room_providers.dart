import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/features/messages/notifiers/chat_room_notifier.dart';
import 'package:mostro_mobile/features/messages/notifiers/chat_rooms_notifier.dart';

final messagesListNotifierProvider =
    StateNotifierProvider<ChatRoomsNotifier, List<ChatRoom>>(
  (ref) => ChatRoomsNotifier(),
);

final messagesDetailNotifierProvider = StateNotifierProvider.family<
    ChatRoomNotifier, ChatRoom, String>((ref, chatId) {
  return ChatRoomNotifier(ChatRoom());
});

final chatRoomsProvider =
    StateNotifierProvider<ChatRoomsNotifier, List<ChatRoom>>((ref) {
  return ChatRoomsNotifier();
});
