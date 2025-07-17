import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/features/chat/widgets/chat_messages_list.dart';
import 'package:mostro_mobile/features/chat/widgets/info_buttons.dart';
import 'package:mostro_mobile/features/chat/widgets/message_input.dart';
import 'package:mostro_mobile/features/chat/widgets/peer_header.dart';
import 'package:mostro_mobile/features/chat/widgets/trade_information_tab.dart';
import 'package:mostro_mobile/features/chat/widgets/user_information_tab.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String orderId;

  const ChatRoomScreen({super.key, required this.orderId});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  String? _selectedInfoType; // null, 'trade', or 'user'

  @override
  Widget build(BuildContext context) {
    final chatDetailState = ref.watch(chatRoomsProvider(widget.orderId));
    final session = ref.read(sessionProvider(widget.orderId));
    final peer = session!.peer!.publicKey;
    final orderState = ref.watch(orderNotifierProvider(widget.orderId));
    final order = orderState.order;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.cream1),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Back',
          style: TextStyle(color: AppTheme.cream1),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            height: 1.0,
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
      resizeToAvoidBottomInset: true, // Resize when keyboard appears
      body: RefreshIndicator(
        onRefresh: () async {},
        child: Stack(
          children: [
            // Main content area
            Padding(
              padding: const EdgeInsets.only(
                  bottom: 80), // Add padding to avoid input bar overlap
              child: Column(
                children: [
                  // Header with peer information
                  PeerHeader(peerPubkey: peer, session: session),

                  // Info buttons
                  InfoButtons(
                    selectedInfoType: _selectedInfoType,
                    onInfoTypeChanged: (type) {
                      setState(() {
                        _selectedInfoType = type;
                      });
                    },
                  ),

                  // Selected info content
                  if (_selectedInfoType == 'trade')
                    TradeInformationTab(order: order, orderId: widget.orderId),
                  if (_selectedInfoType == 'user')
                    UserInformationTab(peerPubkey: peer, session: session),

                  // Chat area
                  Expanded(
                    child: Container(
                      color: AppTheme.backgroundDark,
                      child: Column(
                        children: [
                          Expanded(
                            child: ChatMessagesList(
                              chatRoom: chatDetailState,
                              peerPubkey: peer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Message input positioned above BottomNavBar with padding
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).viewInsets.bottom > 0
                  ? 0 // Cuando el teclado está abierto, posicionar en la parte inferior
                  : 80, // Altura del BottomNavBar según su implementación
              child: MessageInput(
                orderId: widget.orderId,
                selectedInfoType: _selectedInfoType,
                onInfoTypeChanged: (type) {
                  setState(() {
                    _selectedInfoType = type;
                  });
                },
              ),
            ),

            // Position BottomNavBar at the bottom of the screen
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MediaQuery.of(context).viewInsets.bottom > 0
                  ? const SizedBox() // Hide BottomNavBar when keyboard is open
                  : SafeArea(
                      top: false,
                      bottom: true,
                      child: const BottomNavBar(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

}
