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

final chatRoomsProvider =
    StateNotifierProvider.family<ChatRoomNotifier, ChatRoom, String>(
        (ref, chatId) {
  return ChatRoomNotifier(
    ChatRoom(
      orderId: chatId,
      messages: [],
    ),
    chatId,
    ref,
  );
});
