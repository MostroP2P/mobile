import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/shared/providers/avatar_provider.dart';
import 'package:mostro_mobile/shared/providers/legible_hande_provider.dart';
import 'package:mostro_mobile/shared/providers/session_manager_provider.dart';
import 'package:mostro_mobile/shared/widgets/clickable_text_widget.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String orderId;

  const ChatRoomScreen({super.key, required this.orderId});

  @override
  ConsumerState<ChatRoomScreen> createState() => _MessagesDetailScreenState();
}

class _MessagesDetailScreenState extends ConsumerState<ChatRoomScreen> {
  final TextEditingController _textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final chatDetailState = ref.watch(chatRoomsProvider(widget.orderId));
    final session = ref.read(sessionProvider(widget.orderId));
    final peer = session!.peer!.publicKey;

    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'BACK',
          style: TextStyle(
            color: AppTheme.cream1,
            fontFamily: GoogleFonts.robotoCondensed().fontFamily,
          ),
        ),
        leading: IconButton(
          icon: const HeroIcon(
            HeroIcons.arrowLeft,
            color: AppTheme.cream1,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: Container(
          margin: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: AppTheme.dark2,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12.0),
              Text('Order: ${widget.orderId}'),
              _buildMessageHeader(peer, session),
              _buildBody(chatDetailState, peer),
              _buildMessageInput(),
              const SizedBox(height: 12.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ChatRoom state, String peer) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        child: ListView.builder(
          itemCount: state.messages.length,
          itemBuilder: (context, index) {
            final message = state.messages[index];
            return _buildMessageBubble(message, peer);
          },
        ),
      ),
    );
  }

  Widget _buildMessageBubble(NostrEvent message, String peer) {
    final peerBubble = pickNymColor(peer);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      alignment:
          message.pubkey == peer ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.pubkey == peer ? peerBubble : const Color(0xFF8CC541),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.content!,
          style: const TextStyle(color: AppTheme.cream1),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 12, 18),
      color: const Color(0xFF303544),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: AppTheme.cream1),
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
              final text = _textController.text.trim();
              if (text.isNotEmpty) {
                ref
                    .read(chatRoomsProvider(widget.orderId).notifier)
                    .sendMessage(text);
                _textController.clear();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageHeader(String peerPubkey, Session session) {
    final handle = ref.read(nickNameProvider(peerPubkey));
    final you = ref.read(nickNameProvider(session.tradeKey.public));
    final sharedKey = session.sharedKey?.private;

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
            NymAvatar(pubkeyHex: peerPubkey),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You are chatting with $handle',
                    style: const TextStyle(
                      color: AppTheme.cream1,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Your handle: $you'),
                  ClickableText(
                    leftText: 'Your shared key:',
                    clickableText: sharedKey!,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
