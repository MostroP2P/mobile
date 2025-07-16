import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/avatar_provider.dart';
import 'package:mostro_mobile/shared/providers/legible_handle_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/utils/currency_utils.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/shared/widgets/clickable_text_widget.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_bar.dart';
import 'package:intl/intl.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String orderId;

  const ChatRoomScreen({super.key, required this.orderId});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final TextEditingController _textController = TextEditingController();
  String? _selectedInfoType; // null, 'trade', or 'user'

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatDetailState = ref.watch(chatRoomsProvider(widget.orderId));
    final session = ref.read(sessionProvider(widget.orderId));
    final peer = session!.peer!.publicKey;
    final orderState = ref.watch(orderNotifierProvider(widget.orderId));
    final order = orderState.order;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: const MostroAppBar(),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: Stack(
          children: [
            Column(
              children: [
                // Header with peer information
                _buildPeerHeader(peer, session),
                
                // Info buttons
                _buildInfoButtons(context),
                
                // Selected info content
                if (_selectedInfoType == 'trade')
                  _buildTradeInformationTab(order, context),
                if (_selectedInfoType == 'user')
                  _buildUserInformationTab(peer, session),
                
                // Chat area
                Expanded(
                  child: Container(
                    color: AppTheme.backgroundDark,
                    child: Column(
                      children: [
                        Expanded(
                          child: _buildBody(chatDetailState, peer),
                        ),
                        _buildMessageInput(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Position BottomNavBar at the bottom of the screen
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BottomNavBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ChatRoom state, String peer) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppTheme.backgroundDark,
      child: ListView.builder(
        itemCount: state.messages.length,
        itemBuilder: (context, index) {
          final message = state.messages[index];
          return _buildMessageBubble(message, peer);
        },
      ),
    );
  }

  Widget _buildMessageBubble(NostrEvent message, String peer) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      alignment:
          message.pubkey == peer ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.pubkey == peer 
              ? AppTheme.backgroundCard 
              : AppTheme.purpleAccent,
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
      padding: const EdgeInsets.fromLTRB(24, 12, 12, 18),
      color: AppTheme.backgroundDark,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: AppTheme.cream1),
              decoration: InputDecoration(
                hintText: "Type a message",
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppTheme.backgroundInput,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: AppTheme.mostroGreen),
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

  Widget _buildPeerHeader(String peerPubkey, Session session) {
    final handle = ref.read(nickNameProvider(peerPubkey));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          NymAvatar(pubkeyHex: peerPubkey),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  handle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "You are chatting with $handle",
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildInfoButton(context, "Trade Information", "trade"),
          const SizedBox(width: 12),
          _buildInfoButton(context, "User Information", "user"),
        ],
      ),
    );
  }
  
  Widget _buildInfoButton(BuildContext context, String title, String type) {
    final isSelected = _selectedInfoType == type;
    
    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _selectedInfoType = isSelected ? null : type;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? AppTheme.mostroGreen.withOpacity(0.2) : AppTheme.backgroundCard,
          foregroundColor: isSelected ? AppTheme.mostroGreen : AppTheme.textSecondary,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected ? AppTheme.mostroGreen : Colors.transparent,
              width: 1,
            ),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'trade' ? Icons.description_outlined : Icons.person_outline,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTradeInformationTab(Order? order, BuildContext context) {
    if (order == null) {
      return Center(
        child: CircularProgressIndicator(
          color: AppTheme.mostroGreen,
        ),
      );
    }
    
    return Container(
      color: AppTheme.backgroundDark,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order ID
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order ID:',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.orderId,
                  style: const TextStyle(
                    color: AppTheme.cream1,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Order details
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order.kind.value == 'sell' 
                          ? 'Selling ${CurrencyUtils.formatSats(order.amount)} sats'
                          : 'Buying ${CurrencyUtils.formatSats(order.amount)} sats',
                      style: const TextStyle(
                        color: AppTheme.cream1,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: order.status.value == 'active' 
                            ? AppTheme.statusActiveBackground 
                            : AppTheme.statusPendingBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        order.status.value.toUpperCase(),
                        style: TextStyle(
                          color: order.status.value == 'active' 
                              ? AppTheme.statusActiveText 
                              : AppTheme.statusPendingText,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'for ${order.fiatAmount} ${order.fiatCode}',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Payment method
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Method:',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.paymentMethod,
                  style: const TextStyle(
                    color: AppTheme.cream1,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Created date
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Created on:',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.createdAt != null 
                      ? DateFormat('MMMM d, yyyy').format(DateTime.fromMillisecondsSinceEpoch(order.createdAt! * 1000))
                      : 'Unknown date',
                  style: const TextStyle(
                    color: AppTheme.cream1,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildUserInformationTab(String peerPubkey, Session session) {
    final handle = ref.read(nickNameProvider(peerPubkey));
    final you = ref.read(nickNameProvider(session.tradeKey.public));
    final sharedKey = session.sharedKey?.private;
    
    return Container(
      color: AppTheme.backgroundDark,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Peer information
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    NymAvatar(pubkeyHex: peerPubkey),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            handle,
                            style: const TextStyle(
                              color: AppTheme.cream1,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Peer Public Key:',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          ClickableText(
                            leftText: '',
                            clickableText: peerPubkey,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Your information
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Information',
                  style: TextStyle(
                    color: AppTheme.cream1,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your Handle:',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                Text(
                  you,
                  style: const TextStyle(
                    color: AppTheme.cream1,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your Shared Key:',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                ClickableText(
                  leftText: '',
                  clickableText: sharedKey ?? 'Not available',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
