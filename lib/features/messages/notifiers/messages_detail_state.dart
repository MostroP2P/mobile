import 'package:dart_nostr/nostr/model/event/event.dart';

enum MessagesDetailStatus {
  loading,
  loaded,
  error,
}

class MessagesDetailState {
  final MessagesDetailStatus status;
  final List<NostrEvent> messages;
  final String? error;

  const MessagesDetailState({
    this.status = MessagesDetailStatus.loading,
    this.messages = const [],
    this.error,
  });

  MessagesDetailState copyWith({
    MessagesDetailStatus? status,
    List<NostrEvent>? messages,
    String? error,
  }) {
    return MessagesDetailState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      error: error,
    );
  }
}
