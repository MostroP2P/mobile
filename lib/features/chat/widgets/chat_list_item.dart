import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/providers/avatar_provider.dart';
import 'package:mostro_mobile/shared/providers/legible_handle_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';

class ChatListItem extends ConsumerWidget {
  final String orderId;

  const ChatListItem({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider(orderId));
    
    // Check if session or peer is null and return a placeholder widget
    if (session == null || session.peer == null) {
      return _buildPlaceholderItem(context);
    }
    
    final peerPubkey = session.peer!.publicKey;
    final currentUserPubkey = session.tradeKey.public;
    final handle = ref.read(nickNameProvider(peerPubkey));

    // Get actual chat data
    final chatRoom = ref.watch(chatRoomsProvider(orderId));
    final bool isSelling = session.role?.toString() == 'seller';
    final String actionText =
        isSelling ? S.of(context)!.youAreSellingTo : S.of(context)!.youAreBuyingFrom;

    // Get the last message if available
    String messagePreview = S.of(context)!.noMessagesYet;
    String date = S.of(context)!.today; // Default date if no message date is available
    bool hasUnreadMessages = false;
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
      if (lastMessage.pubkey == currentUserPubkey) {
        messagePreview = "${S.of(context)!.youPrefix}$messagePreview";
      }

      // Check for unread messages from the peer (not from current user)
      hasUnreadMessages = false;
      for (final message in sortedMessages) {
        // If message is from peer (not current user) and is recent
        if (message.pubkey == peerPubkey && message.createdAt != null && message.createdAt is int) {
          final messageTime = DateTime.fromMillisecondsSinceEpoch((message.createdAt as int) * 1000);
          final now = DateTime.now();
          final oneHourAgo = now.subtract(const Duration(hours: 1));
          
          if (messageTime.isAfter(oneHourAgo)) {
            hasUnreadMessages = true;
            break;
          }
        }
      }

      // Format the date
      if (lastMessage.createdAt != null && lastMessage.createdAt is int) {
        // Convert Unix timestamp to DateTime (seconds to milliseconds)
        final messageDate = DateTime.fromMillisecondsSinceEpoch(
            (lastMessage.createdAt as int) * 1000);
        date = formatDateTime(context, messageDate);
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
                  NymAvatar(pubkeyHex: peerPubkey),
                  // Role indicator (seller)
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

                  if (hasUnreadMessages)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
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
                            color: AppTheme.backgroundInput.withValues(alpha: 0.5),
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

  // Placeholder widget when session or peer data is not available
  Widget _buildPlaceholderItem(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 13), // 0.05 opacity
            width: 1.0,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(
          children: [
            // Placeholder avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.backgroundDark,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Placeholder for name
                  Container(
                    width: 100,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundDark,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Placeholder for message
                  Container(
                    width: 200,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundDark,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String formatDateTime(BuildContext context, DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dt.year, dt.month, dt.day);

    if (messageDate == today) {
      // If message is from today, show only time
      return DateFormat('HH:mm').format(dt);
    } else if (messageDate == yesterday) {
      // If message is from yesterday, show "Yesterday"
      return S.of(context)!.yesterday;
    } else if (now.difference(dt).inDays < 7) {
      // If message is from this week, show day name
      return DateFormat('EEEE').format(dt); // Full weekday name
    } else {
      // Otherwise show date
      return DateFormat('MMM d').format(dt); // e.g. "Apr 14"
    }
  }
}