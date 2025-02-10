import 'package:dart_nostr/nostr/model/event/event.dart';

enum MessagesListStatus { loading, loaded, error, empty }

class MessagesListState {
  final MessagesListStatus status;
  final List<NostrEvent> chats;
  final String? errorMessage;

  const MessagesListState({
    this.status = MessagesListStatus.loading,
    this.chats = const [],
    this.errorMessage,
  });

  // A copyWith for convenience
  MessagesListState copyWith({
    MessagesListStatus? status,
    List<NostrEvent>? chats,
    String? errorMessage,
  }) {
    return MessagesListState(
      status: status ?? this.status,
      chats: chats ?? this.chats,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
