import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/messages/notifiers/messages_detail_notifier.dart';
import 'package:mostro_mobile/features/messages/notifiers/messages_detail_state.dart';
import 'package:mostro_mobile/features/messages/notifiers/messages_list_notifier.dart';
import 'package:mostro_mobile/features/messages/notifiers/messages_list_state.dart';

final messagesListNotifierProvider =
    StateNotifierProvider<MessagesListNotifier, MessagesListState>(
  (ref) => MessagesListNotifier(),
);

final messagesDetailNotifierProvider = StateNotifierProvider.family<
    MessagesDetailNotifier, MessagesDetailState, String>((ref, chatId) {
  return MessagesDetailNotifier(chatId);
});


