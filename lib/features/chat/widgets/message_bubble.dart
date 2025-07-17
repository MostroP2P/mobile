import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';

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
    );
  }
}