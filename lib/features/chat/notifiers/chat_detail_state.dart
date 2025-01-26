import 'package:dart_nostr/nostr/model/event/event.dart';

enum ChatDetailStatus {
  loading,
  loaded,
  error,
}

class ChatDetailState {
  final ChatDetailStatus status;
  final List<NostrEvent> messages;
  final String? error;

  const ChatDetailState({
    this.status = ChatDetailStatus.loading,
    this.messages = const [],
    this.error,
  });

  ChatDetailState copyWith({
    ChatDetailStatus? status,
    List<NostrEvent>? messages,
    String? error,
  }) {
    return ChatDetailState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      error: error,
    );
  }
}
