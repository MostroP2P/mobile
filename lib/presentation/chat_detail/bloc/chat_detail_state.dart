import 'package:equatable/equatable.dart';

abstract class ChatDetailState extends Equatable {
  const ChatDetailState();

  @override
  List<Object> get props => [];
}

class ChatDetailInitial extends ChatDetailState {}

class ChatDetailLoading extends ChatDetailState {}

class ChatDetailLoaded extends ChatDetailState {
  final List<ChatMessage> messages;

  const ChatDetailLoaded(this.messages);

  @override
  List<Object> get props => [messages];
}

class ChatDetailError extends ChatDetailState {
  final String error;

  const ChatDetailError(this.error);

  @override
  List<Object> get props => [error];
}

class ChatMessage {
  final String id;
  final String sender;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.content,
    required this.timestamp,
  });
}
