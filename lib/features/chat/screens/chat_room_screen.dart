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
  // Constant for BottomNavBar height to ensure consistency
  static const double bottomNavBarHeight = 80;
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
  Widget build(BuildContext context) {
    final chatDetailState = ref.watch(chatRoomsProvider(widget.orderId));
    final chatNotifier = ref.watch(chatRoomsProvider(widget.orderId).notifier);
    final session = ref.read(sessionProvider(widget.orderId));

    final peer = session!.peer!.publicKey;
    final orderState = ref.watch(orderNotifierProvider(widget.orderId));
    final order = orderState.order;
    
    // Check if keyboard is visible
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    
    // If keyboard just became visible, scroll to bottom
    if (isKeyboardVisible && !_wasKeyboardVisible) {
      // Use Future.delayed instead of microtask to ensure the list is built
      Future.delayed(const Duration(milliseconds: 100), () {
        // Verify controller is attached and list has content
        if (_scrollController.hasClients && 
            chatDetailState.messages.isNotEmpty &&
            _scrollController.position.maxScrollExtent > 0) {
          try {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          } catch (e) {
            // Silently handle any scroll errors
            // This prevents exceptions from breaking the UI
          }
        }
      });
    }
    
    // Update keyboard visibility tracking
    _wasKeyboardVisible = isKeyboardVisible;



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
              padding: EdgeInsets.only(
                  // Dynamic bottom padding based on device settings
                  bottom: MediaQuery.textScalerOf(context).scale(1.0) > 1.0
                      ? bottomNavBarHeight + 40 // More padding for zoomed-in text
                      : bottomNavBarHeight + 10), // Normal padding for regular view
              child: Column(
                children: [
                  // Header with peer information
                  PeerHeader(peerPubkey: peer, session: session),


                  // Info buttons
                  InfoButtons(
                    selectedInfoType: _selectedInfoType,
                    onInfoTypeChanged: (type) {
                      // Dismiss keyboard when selecting info tabs to prevent overlap
                      if (type != null) {
                        FocusScope.of(context).unfocus();
                      }
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
                            child: !chatNotifier.isInitialized
                              ? const Center(child: CircularProgressIndicator())
                              : ChatMessagesList(
                                  chatRoom: chatDetailState,
                                  peerPubkey: peer,
                                  scrollController: _scrollController,
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
                  ? 0 // When keyboard is open, position at bottom
                  : bottomNavBarHeight, // Use constant for BottomNavBar height
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.backgroundDark, // Match background color
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey.withValues(alpha: 8), // 0.03 opacity - extremely subtle
                      width: 0.3, // Even thinner line
                    ),
                  ),
                ),
                child: MessageInput(
                  orderId: widget.orderId,
                  selectedInfoType: _selectedInfoType,
                  onInfoTypeChanged: (type) {
                    // Dismiss keyboard when selecting info tabs to prevent overlap
                    if (type != null) {
                      FocusScope.of(context).unfocus();
                    }
                    setState(() {
                      _selectedInfoType = type;
                    });
                  },
                ),
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
