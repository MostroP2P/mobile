import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/chat_room.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/shared/providers/avatar_provider.dart';
import 'package:mostro_mobile/shared/providers/legible_hande_provider.dart';
import 'package:mostro_mobile/shared/providers/session_manager_provider.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_bar.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_drawer.dart';

class ChatRoomsScreen extends ConsumerWidget {
  const ChatRoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatListState = ref.watch(chatRoomsNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: const MostroAppBar(),
      drawer: const MostroAppDrawer(),
      body: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF303544),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'CHAT',
                style: TextStyle(color: AppTheme.mostroGreen),
              ),
            ),
            Expanded(
              child: _buildBody(chatListState),
            ),
            const BottomNavBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<ChatRoom> state) {
    if (state.isEmpty) {
      return Center(
          child: Text(
        'No messages available',
      ));
    }
    return ListView.builder(
      itemCount: state.length,
      itemBuilder: (context, index) {
        return ChatListItem(
          orderId: state[index].orderId,
        );
      },
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
    return GestureDetector(
      onTap: () {
        context.push('/chat_room/$orderId');
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1D212C),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              NymAvatar(pubkeyHex: pubkey),
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
                            color: AppTheme.cream1,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
    final dateFormatter = DateFormat('MMM dd HH:mm:ss');
    final formattedDate = dateFormatter.format(dt);
    return formattedDate;
  }
}
