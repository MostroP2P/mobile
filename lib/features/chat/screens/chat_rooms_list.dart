// NostrEvent is now accessed through ChatRoom model
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/features/chat/widgets/chat_list_item.dart';
import 'package:mostro_mobile/features/chat/widgets/chat_tabs.dart';
import 'package:mostro_mobile/features/chat/widgets/empty_state_view.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
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
                    S.of(context)?.chat ?? 'Chat',
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
                    S.of(context)?.conversationsDescription ?? 'Your conversations with other users will appear here.',
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
                        message: S.of(context)?.noDisputesAvailable ?? 'No disputes available',
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
        message: S.of(context)?.noMessagesAvailable ?? 'No messages available',
      );
    }

    // Get fresh chat data for each order to ensure we have the latest messages
    final chatRoomsWithFreshData = state.map((chatRoom) {
      // Watch the individual chat provider to get the most up-to-date state
      return ref.watch(chatRoomsProvider(chatRoom.orderId));
    }).toList();

    // Sort all chat rooms by session start time (most recently taken order first)
    chatRoomsWithFreshData.sort((a, b) {
      final aSessionStartTime = _getSessionStartTime(a);
      final bSessionStartTime = _getSessionStartTime(b);
      return bSessionStartTime.compareTo(aSessionStartTime);
    });

    return Container(
      color: AppTheme.backgroundDark,
      child: ListView.builder(
        itemCount: chatRoomsWithFreshData.length,
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return ChatListItem(
            orderId: chatRoomsWithFreshData[index].orderId,
          );
        },
      ),
    );
  }

  int _getSessionStartTime(ChatRoom chatRoom) {
    try {
      // Get the session for this chat room to access startTime
      final session = ref.read(sessionProvider(chatRoom.orderId));
      if (session != null) {
        // Return the session start time (when the order was taken/contacted)
        return session.startTime.millisecondsSinceEpoch ~/ 1000;
      }
    } catch (e) {
      // If we can't get the session, fall back to current time
    }
    
    // Fallback: use current time so new chats appear at top
    return DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }
}
