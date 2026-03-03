import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/chat/utils/message_type_helpers.dart';
import 'package:mostro_mobile/features/disputes/notifiers/dispute_chat_notifier.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/utils/snack_bar_helper.dart';

class DisputeMessageBubble extends StatelessWidget {
  final DisputeChatMessage message;
  final bool isFromUser;

  const DisputeMessageBubble({
    super.key,
    required this.message,
    required this.isFromUser,
  });

  @override
  Widget build(BuildContext context) {
    final messageType = MessageTypeUtils.getMessageType(message.event);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      alignment: isFromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment:
            isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
                minWidth: 0,
              ),
              child: _buildBubbleContent(context, messageType),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleContent(
      BuildContext context, MessageContentType messageType) {
    switch (messageType) {
      case MessageContentType.encryptedImage:
        return _buildMediaPlaceholder(context, isImage: true);
      case MessageContentType.encryptedFile:
        return _buildMediaPlaceholder(context, isImage: false);
      case MessageContentType.text:
        return _buildTextBubble(context);
    }
  }

  Widget _buildTextBubble(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _copyToClipboard(context, message.content),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: _bubbleDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: const TextStyle(
                color: AppTheme.cream1,
                fontSize: 16,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            _buildTimestamp(),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPlaceholder(BuildContext context,
      {required bool isImage}) {
    Map<String, dynamic>? metadata;
    try {
      metadata = jsonDecode(message.content) as Map<String, dynamic>;
    } catch (_) {
      // Malformed JSON — fall back to text bubble
      return _buildTextBubble(context);
    }

    final filename = metadata['filename'] as String? ?? '';
    final originalSize = metadata['original_size'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: _bubbleDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isImage ? Icons.image : Icons.insert_drive_file,
                color: AppTheme.cream1,
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  filename,
                  style: const TextStyle(
                    color: AppTheme.cream1,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatFileSize(originalSize),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '·',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.lock,
                color: Colors.white70,
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                S.of(context)!.encrypted,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildTimestamp(),
        ],
      ),
    );
  }

  BoxDecoration _bubbleDecoration() {
    return BoxDecoration(
      color: isFromUser ? AppTheme.purpleButton : _getAdminMessageColor(),
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
        bottomLeft: Radius.circular(isFromUser ? 16 : 4),
        bottomRight: Radius.circular(isFromUser ? 4 : 16),
      ),
    );
  }

  Widget _buildTimestamp() {
    return Text(
      _formatTime(message.timestamp),
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
      ),
    );
  }

  Color _getAdminMessageColor() {
    const Color adminBlue = AppTheme.createdByYouChip;
    final HSVColor hsvColor = HSVColor.fromColor(adminBlue);
    return hsvColor.withSaturation(0.3).withValue(0.25).toColor();
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    SnackBarHelper.showTopSnackBar(
      context,
      S.of(context)!.messageCopiedToClipboard,
      duration: const Duration(seconds: 1),
      backgroundColor: Colors.green,
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
