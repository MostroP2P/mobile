// NostrEvent is now accessed through ChatRoom model
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';

import 'package:mostro_mobile/features/chat/widgets/chat_list_item.dart';
import 'package:mostro_mobile/features/chat/widgets/chat_tabs.dart';
import 'package:mostro_mobile/features/chat/widgets/empty_state_view.dart';
import 'package:mostro_mobile/features/disputes/widgets/disputes_list.dart';
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
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundDark,
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundDark,
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
                    ),
                  ),
                  child: Text(
                    _getTabDescription(context),
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
                // Content area
                Expanded(
                  child: Container(
                    color: AppTheme.backgroundDark,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Messages tab
                        _buildBody(context, chatListState),
                        // Disputes tab
                        const DisputesList(),
                      ],
                    ),
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



    // Use the optimized provider that returns sorted chat rooms with fresh data
    // This prevents excessive rebuilds by memoizing the sorted list
    final chatRoomsWithFreshData = ref.watch(sortedChatRoomsProvider);


    return ListView.builder(
      itemCount: chatRoomsWithFreshData.length,
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return ChatListItem(
          orderId: chatRoomsWithFreshData[index].orderId,
        );
      },
    );
  }

  String _getTabDescription(BuildContext context) {
    if (_tabController.index == 0) {
      // Messages tab
      return S.of(context)?.conversationsDescription ?? 'Here you\'ll find your conversations with other users during trades.';
    } else {
      // Disputes tab
      return 'These are your open disputes and the chats with the admin helping resolve them.';
    }
  }
}
