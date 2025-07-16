import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/shared/providers/avatar_provider.dart';
import 'package:mostro_mobile/shared/providers/legible_handle_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/shared/widgets/custom_drawer_overlay.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_bar.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';

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
                _buildTabs(context),
                // Description text
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  color: AppTheme.backgroundDark,
                  child: Text(
                    "Here you'll find your conversations with other users during trades.",
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
                      Center(
                        child: Text(
                          "No disputes available",
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
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

  Widget _buildTabs(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildTabButton(context, 0, "Messages", _tabController.index == 0),
          _buildTabButton(context, 1, "Disputes", _tabController.index == 1),
        ],
      ),
    );
  }

  Widget _buildTabButton(
      BuildContext context, int index, String text, bool isActive) {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _tabController.animateTo(index);
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppTheme.mostroGreen : Colors.transparent,
                width: 3.0,
              ),
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? AppTheme.mostroGreen : AppTheme.textInactive,
              fontWeight: FontWeight.w600,
              fontSize: 15,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<ChatRoom> state) {
    if (state.isEmpty) {
      return Center(
        child: Text(
          S.of(context)!.noMessagesAvailable,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }
    return Container(
      color: AppTheme.backgroundDark,
      child: ListView.builder(
        itemCount: state.length,
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return ChatListItem(
            orderId: state[index].orderId,
          );
        },
      ),
    );
  }
}

class ChatListItem extends ConsumerWidget {
  final String orderId;

  const ChatListItem({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider(orderId));
    final pubkey = session!.peer!.publicKey;
    final handle = ref.read(nickNameProvider(pubkey));

    // Get actual chat data
    final chatRoom = ref.watch(chatRoomsProvider(orderId));
    final bool isSelling = session.role == 'seller';
    final String actionText =
        isSelling ? "You are selling sats to" : "You are buying sats from";

    // Get the last message if available
    String messagePreview = "No messages yet";
    String date = "Today"; // Default date if no message date is available

    if (chatRoom.messages.isNotEmpty) {
      // Sort messages by creation time (newest first)
      final sortedMessages = List<NostrEvent>.from(chatRoom.messages);

      // Sort by createdAt time (newest first)
      sortedMessages.sort((a, b) {
        final aTime = a.createdAt is int ? a.createdAt as int : 0;
        final bTime = b.createdAt is int ? b.createdAt as int : 0;
        return bTime.compareTo(aTime);
      });

      final lastMessage = sortedMessages.first;
      messagePreview = lastMessage.content ?? "";

      // If message is from the current user, prefix with "You: "
      if (lastMessage.pubkey == pubkey) {
        messagePreview = "You: $messagePreview";
      }

      // Format the date
      if (lastMessage.createdAt != null && lastMessage.createdAt is int) {
        // Convert Unix timestamp to DateTime (seconds to milliseconds)
        final messageDate = DateTime.fromMillisecondsSinceEpoch(
            (lastMessage.createdAt as int) * 1000);
        date = formatDateTime(messageDate);
      } else {}
    }

    return GestureDetector(
      onTap: () {
        context.push('/chat_room/$orderId');
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.05),
              width: 1.0,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with status indicator
              Stack(
                children: [
                  NymAvatar(pubkeyHex: pubkey),
                  if (isSelling)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.backgroundDark,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          handle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundInput.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            date,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$actionText $handle",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      messagePreview,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dt.year, dt.month, dt.day);

    if (messageDate == today) {
      // If message is from today, show only time
      return DateFormat('HH:mm').format(dt);
    } else if (messageDate == yesterday) {
      // If message is from yesterday, show "Yesterday"
      return "Yesterday";
    } else if (now.difference(dt).inDays < 7) {
      // If message is from this week, show day name
      return DateFormat('EEEE').format(dt); // Full weekday name
    } else {
      // Otherwise show date
      return DateFormat('MMM d').format(dt); // e.g. "Apr 14"
    }
  }
}
