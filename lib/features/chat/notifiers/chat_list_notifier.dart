import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chat_list_state.dart';

class ChatListNotifier extends StateNotifier<ChatListState> {
  ChatListNotifier() : super(const ChatListState()) {
    loadChats();
  }

  Future<void> loadChats() async {
    try {
      // 1) Start loading
      state = state.copyWith(status: ChatListStatus.loading);

      // 2) Simulate or fetch real chat data from a repository
      //    For example:
      // final chats = await chatRepository.getAllChats();
      // For now, a mock:
      await Future.delayed(const Duration(seconds: 1)); // simulating network
      final chats = <NostrEvent>[];

      // 3) Loaded
      state = state.copyWith(
        status: ChatListStatus.loaded,
        chats: chats,
        errorMessage: null,
      );
    } catch (e) {
      // On error
      state = state.copyWith(
        status: ChatListStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}
