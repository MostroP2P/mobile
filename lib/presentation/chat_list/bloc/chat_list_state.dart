import 'package:equatable/equatable.dart';
import 'package:mostro_mobile/data/models/chat_model.dart';

enum ChatListStatus { initial, loading, loaded, error }

class ChatListState extends Equatable {
  final ChatListStatus status;
  final List<ChatModel> chats;
  final String? errorMessage;

  const ChatListState({
    this.status = ChatListStatus.initial,
    this.chats = const [],
    this.errorMessage,
  });

  ChatListState copyWith({
    ChatListStatus? status,
    List<ChatModel>? chats,
    String? errorMessage,
  }) {
    return ChatListState(
      status: status ?? this.status,
      chats: chats ?? this.chats,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, chats, errorMessage];
}
