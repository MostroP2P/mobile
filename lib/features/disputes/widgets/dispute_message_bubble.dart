import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/shared/utils/datetime_extensions_utils.dart';
import 'package:mostro_mobile/features/chat/utils/message_type_helpers.dart';
import 'package:mostro_mobile/features/chat/widgets/encrypted_image_message.dart';
import 'package:mostro_mobile/features/chat/widgets/encrypted_file_message.dart';
import 'package:mostro_mobile/features/disputes/notifiers/dispute_chat_notifier.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/utils/snack_bar_helper.dart';

class DisputeMessageBubble extends ConsumerWidget {
  final DisputeChatMessage message;
  final bool isFromUser;
  final String disputeId;

  const DisputeMessageBubble({
    super.key,
    required this.message,
    required this.isFromUser,
    required this.disputeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              child: _buildBubbleContent(context, ref, messageType),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleContent(
      BuildContext context, WidgetRef ref, MessageContentType messageType) {
    switch (messageType) {
      case MessageContentType.encryptedImage:
        return _buildMultimediaWidget(context, ref, isImage: true);
      case MessageContentType.encryptedFile:
        return _buildMultimediaWidget(context, ref, isImage: false);
      case MessageContentType.text:
        return _buildTextBubble(context);
    }
  }

  Widget _buildMultimediaWidget(BuildContext context, WidgetRef ref,
      {required bool isImage}) {
    final notifier =
        ref.read(disputeChatNotifierProvider(disputeId).notifier);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: _bubbleDecoration(),
      child: isImage
          ? EncryptedImageMessage(
              message: message.event,
              isOwnMessage: isFromUser,
              getSharedKey: notifier.getAdminSharedKey,
              getCachedImage: notifier.getCachedImage,
              getImageMetadata: notifier.getImageMetadata,
              cacheDecryptedImage: notifier.cacheDecryptedImage,
            )
          : EncryptedFileMessage(
              message: message.event,
              isOwnMessage: isFromUser,
              getSharedKey: notifier.getAdminSharedKey,
              getCachedFile: notifier.getCachedFile,
              getFileMetadata: notifier.getFileMetadata,
              cacheDecryptedFile: notifier.cacheDecryptedFile,
            ),
    );
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
            _buildTimestamp(context),
          ],
        ),
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

  Widget _buildTimestamp(BuildContext context) {
    return Text(
      message.timestamp.timeAgoWithLocale(context),
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

}
