import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/providers/avatar_provider.dart';
import 'package:mostro_mobile/shared/providers/legible_handle_provider.dart';
import 'package:mostro_mobile/shared/widgets/clickable_text_widget.dart';

class UserInformationTab extends ConsumerWidget {
  final String peerPubkey;
  final Session session;

  const UserInformationTab({
    super.key,
    required this.peerPubkey,
    required this.session,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handle = ref.read(nickNameProvider(peerPubkey));
    final you = ref.read(nickNameProvider(session.tradeKey.public));
    final sharedKey = session.sharedKey?.private;

    return Container(
      color: AppTheme.backgroundDark,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Peer information
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                              color: AppTheme.cream1,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            S.of(context)!.peerPublicKey,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          ClickableText(
                            leftText: '',
                            clickableText: peerPubkey,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Your information
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.yourInformation,
                  style: const TextStyle(
                    color: AppTheme.cream1,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  S.of(context)!.yourHandle,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                Text(
                  you,
                  style: const TextStyle(
                      color: AppTheme.cream1,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  S.of(context)!.yourSharedKey,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                ClickableText(
                  leftText: '',
                  clickableText: sharedKey ?? S.of(context)!.notAvailable,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}