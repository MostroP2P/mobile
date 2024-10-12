import 'package:equatable/equatable.dart';

abstract class ChatDetailEvent extends Equatable {
  const ChatDetailEvent();

  @override
  List<Object> get props => [];
}

class LoadChatDetail extends ChatDetailEvent {
  final String chatId;

  const LoadChatDetail(this.chatId);

  @override
  List<Object> get props => [chatId];
}

class SendMessage extends ChatDetailEvent {
  final String message;

  const SendMessage(this.message);

  @override
  List<Object> get props => [message];
}
