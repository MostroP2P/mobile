import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/chat_detail_bloc.dart';
import '../bloc/chat_detail_event.dart';
import '../bloc/chat_detail_state.dart';
import '../../widgets/bottom_nav_bar.dart';

class ChatDetailScreen extends StatelessWidget {
  final String chatId;

  const ChatDetailScreen({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChatDetailBloc()..add(LoadChatDetail(chatId)),
      child: Scaffold(
        backgroundColor: const Color(0xFF1D212C),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('JACK FOOTSEY'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: BlocBuilder<ChatDetailBloc, ChatDetailState>(
          builder: (context, state) {
            if (state is ChatDetailLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is ChatDetailLoaded) {
              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.messages.length,
                      itemBuilder: (context, index) {
                        final message = state.messages[index];
                        return _buildMessageBubble(message);
                      },
                    ),
                  ),
                  _buildMessageInput(context),
                ],
              );
            } else if (state is ChatDetailError) {
              return Center(child: Text(state.error));
            } else {
              return const Center(child: Text('Something went wrong'));
            }
          },
        ),
        bottomNavigationBar: const BottomNavBar(),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      alignment: message.sender == 'Mostro' ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.sender == 'Mostro' ? const Color(0xFF303544) : const Color(0xFF8CC541),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.content,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildMessageInput(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    return Container(
      padding: const EdgeInsets.all(8),
      color: const Color(0xFF303544),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFF1D212C),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF8CC541)),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<ChatDetailBloc>().add(SendMessage(controller.text));
                controller.clear();
              }
            },
          ),
        ],
      ),
    );
  }
}