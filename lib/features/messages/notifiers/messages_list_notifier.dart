import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'messages_list_state.dart';

class MessagesListNotifier extends StateNotifier<MessagesListState> {
  MessagesListNotifier() : super(const MessagesListState()) {
    loadChats();
  }

  Future<void> loadChats() async {
    try {
      // 1) Start loading
      state = state.copyWith(status: MessagesListStatus.loading);

      // 2) Simulate or fetch real chat data from a repository
      //    For example:
      // final chats = await chatRepository.getAllChats();
      // For now, a mock:
      await Future.delayed(const Duration(seconds: 1)); // simulating network
      final chats = <NostrEvent>[];

      // 3) Loaded
      state = state.copyWith(
        status: MessagesListStatus.loaded,
        chats: chats,
        errorMessage: null,
      );
    } catch (e) {
      // On error
      state = state.copyWith(
        status: MessagesListStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}
