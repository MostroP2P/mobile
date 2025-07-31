import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/providers/avatar_provider.dart';

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
    final content = message.content;
    
    // Return empty container if message content is null
    if (content == null) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      alignment: isFromPeer ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisAlignment: isFromPeer ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75, // Max 75% of screen width
                minWidth: 0,
              ),
              child: GestureDetector(
                onLongPress: () => _copyToClipboard(context, content),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isFromPeer ? _getPeerMessageColor(peerPubkey) : AppTheme.purpleAccent,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isFromPeer ? 4 : 16),
                      bottomRight: Radius.circular(isFromPeer ? 16 : 4),
                    ),
                  ),
                  child: Text(
                    content,
                    style: const TextStyle(
                      color: AppTheme.cream1,
                      fontSize: 16,
                      height: 1.4, // Better line height for readability
                    ),
                    softWrap: true,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    // Only copy if text is not empty
    if (text.isNotEmpty) {
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
  
  /// Returns a subdued version of the peer's avatar color for message bubbles
  Color _getPeerMessageColor(String pubkey) {
    // Get the original avatar color
    final avatarColor = pickNymColor(pubkey);
    
    // Create a subdued version by reducing saturation and value
    final HSVColor hsvColor = HSVColor.fromColor(avatarColor);
    
    // Create a more subdued version with lower saturation and value
    // but keep enough color to be recognizable
    return hsvColor.withSaturation(0.3).withValue(0.25).toColor();
  }
}