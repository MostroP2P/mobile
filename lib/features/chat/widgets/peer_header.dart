import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/shared/providers/avatar_provider.dart';
import 'package:mostro_mobile/shared/providers/legible_handle_provider.dart';

class PeerHeader extends ConsumerWidget {
  final String peerPubkey;
  final Session session;

  const PeerHeader({
    super.key,
    required this.peerPubkey,
    required this.session,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handle = ref.read(nickNameProvider(peerPubkey));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          NymAvatar(pubkeyHex: peerPubkey),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  handle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "You are chatting with $handle",
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}