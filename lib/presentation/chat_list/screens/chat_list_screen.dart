import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mostro_mobile/data/models/chat_model.dart';
import 'package:mostro_mobile/presentation/chat_list/bloc/chat_list_bloc.dart';
import 'package:mostro_mobile/presentation/chat_list/bloc/chat_list_event.dart';
import 'package:mostro_mobile/presentation/chat_list/bloc/chat_list_state.dart';
import 'package:mostro_mobile/presentation/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/presentation/widgets/custom_app_bar.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChatListBloc()..add(LoadChatList()),
      child: Scaffold(
        backgroundColor: const Color(0xFF1D212C),
        appBar: const CustomAppBar(),
        body: Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF303544),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Chats',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: BlocBuilder<ChatListBloc, ChatListState>(
                  builder: (context, state) {
                    if (state.status == ChatListStatus.loading) {
                      return Center(child: CircularProgressIndicator());
                    } else if (state.status == ChatListStatus.loaded) {
                      return ListView.builder(
                        itemCount: state.chats.length,
                        itemBuilder: (context, index) {
                          return ChatListItem(chat: state.chats[index]);
                        },
                      );
                    } else if (state.status == ChatListStatus.error) {
                      return Center(
                          child:
                              Text(state.errorMessage ?? 'An error occurred'));
                    } else {
                      return Center(child: Text('No chats available'));
                    }
                  },
                ),
              ),
              const BottomNavBar(),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatListItem extends StatelessWidget {
  final ChatModel chat;

  const ChatListItem({Key? key, required this.chat}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D212C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey,
              child: Text(
                chat.username[0],
                style: TextStyle(color: Colors.white),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        chat.username,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        chat.timeAgo,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    chat.lastMessage,
                    style: TextStyle(color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (chat.isUnread)
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Color(0xFF8CC541),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
