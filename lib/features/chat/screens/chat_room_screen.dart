import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/features/chat/widgets/chat_error_screen.dart';
import 'package:mostro_mobile/services/logger_service.dart';
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

  // Scroll controller for the chat messages list
  final ScrollController _scrollController = ScrollController();

  // Track keyboard visibility to trigger scroll
  bool _wasKeyboardVisible = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    if (isKeyboardVisible && !_wasKeyboardVisible) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients &&
            _scrollController.position.maxScrollExtent > 0) {
          try {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          } catch (e) {
            // Silently handle any scroll errors
          }
        }
      });
    }

    _wasKeyboardVisible = isKeyboardVisible;
  }

  /// Shared callback for dismissing keyboard and updating info type selection.
  void _handleInfoTypeChanged(String? type) {
    if (type != null) {
      FocusScope.of(context).unfocus();
    }
    setState(() {
      _selectedInfoType = type;
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatDetailState = ref.watch(chatRoomsProvider(widget.orderId));
    final chatNotifier = ref.watch(chatRoomsProvider(widget.orderId).notifier);
    final session = ref.read(sessionProvider(widget.orderId));
    
    // Validate session exists
    if (session == null) {
      logger.e('ChatRoomScreen: Session not found for order ${widget.orderId}');
      return ChatErrorScreen.sessionNotFound(context);
    }
    // Validate peer exists
    if (session.peer == null) {
      logger.e(
          'ChatRoomScreen: Peer not found in session for order ${widget.orderId}');
      return ChatErrorScreen.peerUnavailable(context);
    }

    final peer = session.peer!.publicKey;
    final orderState = ref.watch(orderNotifierProvider(widget.orderId));
    final order = orderState.order;

    // Check if keyboard is visible
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

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
      body: Column(
        children: [
          // Header with peer information
          PeerHeader(peerPubkey: peer, session: session),

          // Info buttons
          InfoButtons(
            selectedInfoType: _selectedInfoType,
            onInfoTypeChanged: _handleInfoTypeChanged,
          ),

          // Selected info content
          if (_selectedInfoType == 'trade')
            TradeInformationTab(
              order: order?.copyWith(status: orderState.status),
              orderId: widget.orderId,
            ),
          if (_selectedInfoType == 'user')
            UserInformationTab(peerPubkey: peer, session: session),

          // Chat area
          Expanded(
            child: !chatNotifier.isInitialized
                ? const Center(child: CircularProgressIndicator())
                : ChatMessagesList(
                    chatRoom: chatDetailState,
                    peerPubkey: peer,
                    orderId: widget.orderId,
                    scrollController: _scrollController,
                  ),
          ),

          // Message input
          Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundDark,
              border: Border(
                top: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.15),
                  width: 0.5,
                ),
              ),
            ),
            child: MessageInput(
              orderId: widget.orderId,
              selectedInfoType: _selectedInfoType,
              onInfoTypeChanged: _handleInfoTypeChanged,
            ),
          ),

          // Bottom nav bar (hidden when keyboard is open)
          if (!isKeyboardVisible)
            SafeArea(
              top: false,
              bottom: true,
              child: const BottomNavBar(),
            ),
        ],
      ),
    );
  }
}
