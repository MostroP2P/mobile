import 'package:dart_nostr/nostr/model/event/event.dart';

enum ChatListStatus { loading, loaded, error, empty }

class ChatListState {
  final ChatListStatus status;
  final List<NostrEvent> chats;
  final String? errorMessage;

  const ChatListState({
    this.status = ChatListStatus.loading,
    this.chats = const [],
    this.errorMessage,
  });

  // A copyWith for convenience
  ChatListState copyWith({
    ChatListStatus? status,
    List<NostrEvent>? chats,
    String? errorMessage,
  }) {
    return ChatListState(
      status: status ?? this.status,
      chats: chats ?? this.chats,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
