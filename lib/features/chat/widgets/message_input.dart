import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';

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

  @override
  void initState() {
    super.initState();
    // Add listener to focus node to detect keyboard visibility changes
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }
  
  // Handle focus changes to detect keyboard visibility
  void _onFocusChange() {
    if (_focusNode.hasFocus && widget.selectedInfoType != null) {
      // Close info panels when keyboard opens
      widget.onInfoTypeChanged(null);
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty && !_isOrderCompleted()) {
      ref
          .read(chatRoomsProvider(widget.orderId).notifier)
          .sendMessage(text);
      _textController.clear();
    }
  }

  bool _isOrderCompleted() {
    final orderState = ref.watch(orderNotifierProvider(widget.orderId));
    final status = orderState.status;
    
    // Disable messaging for completed, canceled, or expired orders
    final isCompleted = status == Status.success ||
                       status == Status.canceled ||
                       status == Status.canceledByAdmin ||
                       status == Status.settledByAdmin ||
                       status == Status.completedByAdmin ||
                       status == Status.expired ||
                       status == Status.cooperativelyCanceled;
    
    return isCompleted;
  }

  String _getDisabledMessage(BuildContext context, Status? status) {
    final l10n = S.of(context);
    
    switch (status) {
      case Status.success:
        return l10n?.invalidOrderStatus ?? 'Order completed - messaging disabled';
      case Status.canceled:
      case Status.canceledByAdmin:
      case Status.cooperativelyCanceled:
        return l10n?.orderAlreadyCanceled ?? 'Order canceled - messaging disabled';
      case Status.expired:
        return l10n?.invalidOrderStatus ?? 'Order expired - messaging disabled';
      case Status.settledByAdmin:
      case Status.completedByAdmin:
        return l10n?.invalidOrderStatus ?? 'Order settled - messaging disabled';
      default:
        return l10n?.invalidOrderStatus ?? 'Order is no longer active - messaging disabled';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOrderCompleted = _isOrderCompleted();
    final status = ref.watch(orderNotifierProvider(widget.orderId)).status;

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
          if (isOrderCompleted) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.1),
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.textSecondary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getDisabledMessage(context, status),
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 12 + MediaQuery.of(context).padding.bottom,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundInput,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      enabled: !isOrderCompleted,
                      style: TextStyle(
                        color: isOrderCompleted ? AppTheme.textSecondary : AppTheme.cream1,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: S.of(context)?.typeAMessage ?? 'Type a message...',
                        hintStyle: TextStyle(
                            color: AppTheme.textSecondary.withValues(alpha: 153), // 0.6 opacity
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
                      onSubmitted: isOrderCompleted ? null : (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isOrderCompleted ? AppTheme.textSecondary : AppTheme.mostroGreen,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.send,
                      color: isOrderCompleted ? AppTheme.backgroundDark : Colors.white,
                      size: 20,
                    ),
                    onPressed: isOrderCompleted ? null : _sendMessage,
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