import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class MessageBubble extends StatelessWidget {
  final NostrEvent message;
  final String peerPubkey;

  const MessageBubble({
    super.key,
    required this.message,
    required this.peerPubkey,
  });

  @override
  Widget build(BuildContext context) {
    final isFromPeer = message.pubkey == peerPubkey;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      alignment: isFromPeer ? Alignment.centerLeft : Alignment.centerRight,
      child: GestureDetector(
        onLongPress: () => _copyToClipboard(context, message.content!),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isFromPeer ? AppTheme.backgroundCard : AppTheme.purpleAccent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.content!,
            style: const TextStyle(color: AppTheme.cream1),
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context)!.messageCopiedToClipboard),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.backgroundCard,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}