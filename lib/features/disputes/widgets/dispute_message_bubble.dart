import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class DisputeMessageBubble extends StatelessWidget {
  final String message;
  final bool isFromUser;
  final DateTime timestamp;
  final String? adminPubkey;

  const DisputeMessageBubble({
    super.key,
    required this.message,
    required this.isFromUser,
    required this.timestamp,
    this.adminPubkey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      alignment: isFromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75, // Max 75% of screen width
                minWidth: 0,
              ),
              child: GestureDetector(
                onLongPress: () => _copyToClipboard(context, message),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isFromUser ? AppTheme.purpleAccent : _getAdminMessageColor(),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isFromUser ? 16 : 4),
                      bottomRight: Radius.circular(isFromUser ? 4 : 16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message,
                        style: const TextStyle(
                          color: AppTheme.cream1,
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatTime(timestamp),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getAdminMessageColor() {
    // Use admin blue color with same transparency approach as peer messages
    const Color adminBlue = AppTheme.createdByYouChip;
    
    // Create a subdued version by reducing saturation and value like peer messages
    final HSVColor hsvColor = HSVColor.fromColor(adminBlue);
    
    // Create a more subdued version with lower saturation and value
    // but keep enough color to be recognizable (same logic as peer messages)
    return hsvColor.withSaturation(0.3).withValue(0.25).toColor();
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context)?.messageCopiedToClipboard ?? 'Message copied to clipboard'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      // Format as date for older messages
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}