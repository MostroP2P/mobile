import 'package:flutter_bloc/flutter_bloc.dart';
import 'chat_detail_event.dart';
import 'chat_detail_state.dart';

class ChatDetailBloc extends Bloc<ChatDetailEvent, ChatDetailState> {
  ChatDetailBloc() : super(ChatDetailInitial()) {
    on<LoadChatDetail>(_onLoadChatDetail);
    on<SendMessage>(_onSendMessage);
  }

  void _onLoadChatDetail(LoadChatDetail event, Emitter<ChatDetailState> emit) {
    //TODO: Implementar lógica para cargar los detalles del chat
  }

  void _onSendMessage(SendMessage event, Emitter<ChatDetailState> emit) {
    //TODO: Implementar lógica para enviar un mensaje
  }
}
