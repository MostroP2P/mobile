import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/utils/chat_file_upload_helper.dart';

class MessageInput extends ConsumerStatefulWidget {
  final String orderId;
  final String? selectedInfoType;
  final ValueChanged<String?> onInfoTypeChanged;

  const MessageInput({
    super.key,
    required this.orderId,
    required this.selectedInfoType,
    required this.onInfoTypeChanged,
  });

  @override
  ConsumerState<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends ConsumerState<MessageInput> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isUploadingFile = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && widget.selectedInfoType != null) {
      widget.onInfoTypeChanged(null);
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      ref
          .read(chatRoomsProvider(widget.orderId).notifier)
          .sendMessage(text);
      _textController.clear();
      _focusNode.requestFocus();
    }
  }

  Future<void> _selectAndUploadFile() async {
    setState(() => _isUploadingFile = true);

    try {
      final chatNotifier =
          ref.read(chatRoomsProvider(widget.orderId).notifier);

      await ChatFileUploadHelper.selectAndUploadFile(
        context: context,
        getSharedKey: chatNotifier.getSharedKey,
        sendMessage: (json) => chatNotifier.sendMessage(json),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 12,
            ),
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
                            color: AppTheme.textSecondary.withValues(alpha: 0.6),
                            fontSize: 15),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        ],
      ),
    );
  }
}
