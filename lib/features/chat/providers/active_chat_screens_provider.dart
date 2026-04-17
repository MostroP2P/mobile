import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks which chat screens are currently open in the foreground so that
/// incoming chat events can suppress the in-app snackbar when the user is
/// already reading the conversation.
///
/// The set stores opaque chat identifiers (order IDs for P2P chats, dispute
/// IDs for dispute chats). Both spaces are disjoint in practice, so a single
/// set is sufficient.
class ActiveChatScreensNotifier extends StateNotifier<Set<String>> {
  ActiveChatScreensNotifier() : super(const <String>{});

  void register(String chatId) {
    if (state.contains(chatId)) return;
    state = {...state, chatId};
  }

  void unregister(String chatId) {
    if (!state.contains(chatId)) return;
    state = state.where((id) => id != chatId).toSet();
  }

  bool isActive(String chatId) => state.contains(chatId);
}

final activeChatScreensProvider =
    StateNotifierProvider<ActiveChatScreensNotifier, Set<String>>(
  (ref) => ActiveChatScreensNotifier(),
);
