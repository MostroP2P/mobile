import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chat_detail_state.dart';

class ChatDetailNotifier extends StateNotifier<ChatDetailState> {
  final String chatId;

  ChatDetailNotifier(this.chatId) : super(const ChatDetailState()) {
    loadChatDetail();
  }

  Future<void> loadChatDetail() async {
    try {
      state = state.copyWith(status: ChatDetailStatus.loading);

      // Simulate a delay / fetch from repo
      await Future.delayed(const Duration(seconds: 1));
      // Example data
      final chatMessages = <NostrEvent>[];

      state = state.copyWith(
        status: ChatDetailStatus.loaded,
        messages: chatMessages,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: ChatDetailStatus.error,
        error: e.toString(),
      );
    }
  }

  void sendMessage(String text) {
    final updated = List<NostrEvent>.from(state.messages);
    state = state.copyWith(messages: updated);
  }
}
