import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/shared/providers/avatar_provider.dart';
import 'package:mostro_mobile/shared/providers/legible_handle_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';

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
    final bool isSelling = session.role?.value == 'seller';
    final String actionText =
        isSelling ? "You are selling sats to" : "You are buying sats from";

    // Get the last message if available
    String messagePreview = "No messages yet";
    String date = "Today"; // Default date if no message date is available
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
      if (lastMessage.pubkey == pubkey) {
        messagePreview = "You: $messagePreview";
      }

      hasUnreadMessages = false;

      /*
      // Verificar si hay mensajes recientes (menos de 1 hora) que no son del usuario
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      
      for (final message in sortedMessages) {
        // Si el mensaje no es del usuario actual y es reciente
        if (message.pubkey != pubkey && message.createdAt != null && message.createdAt is int) {
          final messageTime = DateTime.fromMillisecondsSinceEpoch((message.createdAt as int) * 1000);
          if (messageTime.isAfter(oneHourAgo)) {
            hasUnreadMessages = true;
            break;
          }
        }
      }
      */

      if (orderId.toLowerCase().contains("fiery")) {
        hasUnreadMessages = true;
      } else {
        hasUnreadMessages = false;
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
                  // Indicador de rol (vendedor)
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