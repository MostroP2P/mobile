import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mostro_mobile/data/models/chat_model.dart';
import 'chat_list_event.dart';
import 'chat_list_state.dart';

class ChatListBloc extends Bloc<ChatListEvent, ChatListState> {
  ChatListBloc() : super(const ChatListState()) {
    on<LoadChatList>(_onLoadChatList);
  }

  void _onLoadChatList(LoadChatList event, Emitter<ChatListState> emit) {
    emit(state.copyWith(status: ChatListStatus.loading));

    // Simulamos la carga de chats (reemplaza esto con una llamada real a tu repositorio o API)
    final chats = [
      ChatModel(
        id: '1',
        username: 'Alice',
        lastMessage: 'Hey, are you still interested in the trade?',
        timeAgo: '5m ago',
        isUnread: true,
      ),
      ChatModel(
        id: '2',
        username: 'Bob',
        lastMessage: 'Thanks for the trade!',
        timeAgo: '2h ago',
      ),
      ChatModel(
        id: '3',
        username: 'Charlie',
        lastMessage: "I've sent the payment. Please confirm.",
        timeAgo: '1d ago',
      ),
    ];

    emit(state.copyWith(
      status: ChatListStatus.loaded,
      chats: chats,
    ));
  }
}
