import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/features/chat/widgets/message_bubble.dart';

class ChatMessagesList extends StatelessWidget {
  final ChatRoom chatRoom;
  final String peerPubkey;

  const ChatMessagesList({
    super.key,
    required this.chatRoom,
    required this.peerPubkey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppTheme.backgroundDark,
      child: ListView.builder(
        itemCount: chatRoom.messages.length,
        itemBuilder: (context, index) {
          final message = chatRoom.messages[index];
          return MessageBubble(
            message: message,
            peerPubkey: peerPubkey,
          );
        },
      ),
    );
  }
}