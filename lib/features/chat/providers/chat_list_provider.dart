import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/chat/notifiers/chat_detail_notifier.dart';
import 'package:mostro_mobile/features/chat/notifiers/chat_detail_state.dart';
import 'package:mostro_mobile/features/chat/notifiers/chat_list_notifier.dart';
import 'package:mostro_mobile/features/chat/notifiers/chat_list_state.dart';

final chatListNotifierProvider =
    StateNotifierProvider<ChatListNotifier, ChatListState>(
  (ref) => ChatListNotifier(),
);

final chatDetailNotifierProvider = StateNotifierProvider.family<
    ChatDetailNotifier, ChatDetailState, String>((ref, chatId) {
  return ChatDetailNotifier(chatId);
});