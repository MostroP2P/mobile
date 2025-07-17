import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/features/chat/widgets/chat_list_item.dart';
import 'package:mostro_mobile/features/chat/widgets/chat_tabs.dart';
import 'package:mostro_mobile/features/chat/widgets/empty_state_view.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/shared/widgets/custom_drawer_overlay.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_bar.dart';

class ChatRoomsScreen extends ConsumerStatefulWidget {
  const ChatRoomsScreen({super.key});

  @override
  ConsumerState<ChatRoomsScreen> createState() => _ChatRoomsScreenState();
}

class _ChatRoomsScreenState extends ConsumerState<ChatRoomsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatListState = ref.watch(chatRoomsNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: const MostroAppBar(),
      body: CustomDrawerOverlay(
        child: Stack(
          children: [
            Column(
              children: [
                // Header with title
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundDark,
                    border: Border(
                      bottom: BorderSide(color: Colors.white24, width: 0.5),
                    ),
                  ),
                  child: Text(
                    S.of(context)!.chat,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Tab bar
                ChatTabs(
                  tabController: _tabController,
                  onTabChanged: () {
                    setState(() {});
                  },
                ),
                // Description text
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  color: AppTheme.backgroundDark,
                  child: Text(
                    S.of(context)!.conversationsDescription,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
                // Content area
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Messages tab
                      _buildBody(context, chatListState),
                      // Disputes tab (placeholder for now)
                      EmptyStateView(
                        message: S.of(context)!.noDisputesAvailable,
                      ),
                    ],
                  ),
                ),
                // Add bottom padding to prevent content from being covered by BottomNavBar
                SizedBox(
                    height: 80 + MediaQuery.of(context).viewPadding.bottom),
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


  Widget _buildBody(BuildContext context, List<ChatRoom> state) {
    if (state.isEmpty) {
      return EmptyStateView(
        message: S.of(context)!.noMessagesAvailable,
      );
    }

    final sortedChatRooms = List<ChatRoom>.from(state);

    // Sort all chat rooms by most recent message time (newest first)
    sortedChatRooms.sort((a, b) {
      final aLastMessageTime = _getLastMessageTime(a);
      final bLastMessageTime = _getLastMessageTime(b);
      return bLastMessageTime.compareTo(aLastMessageTime);
    });

    // Special handling for "hungry" chat - move to top if it exists
    if (sortedChatRooms.length > 1) {
      int hungryIndex = sortedChatRooms
          .indexWhere((chat) => chat.orderId.toLowerCase().contains('hungry'));

      if (hungryIndex != -1 && hungryIndex != 0) {
        final hungryChat = sortedChatRooms.removeAt(hungryIndex);
        sortedChatRooms.insert(0, hungryChat);
      }
    }

    return Container(
      color: AppTheme.backgroundDark,
      child: ListView.builder(
        itemCount: sortedChatRooms.length,
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return ChatListItem(
            orderId: sortedChatRooms[index].orderId,
          );
        },
      ),
    );
  }

  int _getLastMessageTime(ChatRoom chatRoom) {
    if (chatRoom.messages.isEmpty) {
      return 0;
    }

    final sortedMessages = List<NostrEvent>.from(chatRoom.messages);
    sortedMessages.sort((a, b) {
      final aTime = a.createdAt is int ? a.createdAt as int : 0;
      final bTime = b.createdAt is int ? b.createdAt as int : 0;

      return bTime.compareTo(aTime);
    });

    if (sortedMessages.first.createdAt != null &&
        sortedMessages.first.createdAt is int) {
      final timestamp = sortedMessages.first.createdAt as int;

      return timestamp;
    }

    return 0;
  }
}

