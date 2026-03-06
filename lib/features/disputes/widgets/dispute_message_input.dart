import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/disputes/notifiers/dispute_chat_notifier.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/utils/chat_file_upload_helper.dart';

class DisputeMessageInput extends ConsumerStatefulWidget {
  final String disputeId;

  const DisputeMessageInput({
    super.key,
    required this.disputeId,
  });

  @override
  ConsumerState<DisputeMessageInput> createState() =>
      _DisputeMessageInputState();
}

class _DisputeMessageInputState extends ConsumerState<DisputeMessageInput> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isUploadingFile = false;

  @override
  void dispose() {
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      ref
          .read(disputeChatNotifierProvider(widget.disputeId).notifier)
          .sendMessage(text);
      _textController.clear();
      _focusNode.requestFocus();
    }
  }

  Future<void> _selectAndUploadFile() async {
    setState(() => _isUploadingFile = true);

    try {
      final notifier =
          ref.read(disputeChatNotifierProvider(widget.disputeId).notifier);

      await ChatFileUploadHelper.selectAndUploadFile(
        context: context,
        getSharedKey: notifier.getAdminSharedKey,
        sendMessage: (json) => notifier.sendMessage(json),
        isMounted: () => mounted,
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingFile = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Attach file button
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundDark,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.textSecondary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: _isUploadingFile
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppTheme.cream1,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          Icons.attach_file,
                          color: AppTheme.cream1,
                          size: 20,
                        ),
                  onPressed: _isUploadingFile ? null : _selectAndUploadFile,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              const SizedBox(width: 8),
              // Text input field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundInput,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    enabled: true,
                    style: TextStyle(
                      color: AppTheme.cream1,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: S.of(context)!.typeAMessage,
                      hintStyle: TextStyle(
                          color:
                              AppTheme.textSecondary.withValues(alpha: 0.6),
                          fontSize: 15),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Send button
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.mostroGreen,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.send,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: _sendMessage,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
