import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'messages_detail_state.dart';

class MessagesDetailNotifier extends StateNotifier<MessagesDetailState> {
  final String chatId;

  MessagesDetailNotifier(this.chatId) : super(const MessagesDetailState()) {
    loadChatDetail();
  }

  Future<void> loadChatDetail() async {
    try {
      state = state.copyWith(status: MessagesDetailStatus.loading);

      // Simulate a delay / fetch from repo
      await Future.delayed(const Duration(seconds: 1));
      // Example data
      final chatMessages = <NostrEvent>[];

      state = state.copyWith(
        status: MessagesDetailStatus.loaded,
        messages: chatMessages,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: MessagesDetailStatus.error,
        error: e.toString(),
      );
    }
  }

  void sendMessage(String text) {
    final updated = List<NostrEvent>.from(state.messages);
    state = state.copyWith(messages: updated);
  }
}
