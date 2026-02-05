import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/utils/snack_bar_helper.dart';

class DisputeInputSection extends StatefulWidget {
  final String disputeId;

  const DisputeInputSection({
    super.key,
    required this.disputeId,
  });

  @override
  State<DisputeInputSection> createState() => _DisputeInputSectionState();
}

class _DisputeInputSectionState extends State<DisputeInputSection> {
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 40,
                  maxHeight: 120,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: S.of(context)?.typeYourMessage ?? 'Type your message...',
                    hintStyle: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isLoading ? null : _sendMessage,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _canSend() ? Colors.blue : Colors.grey[600],
                  shape: BoxShape.circle,
                ),
                child: _isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canSend() {
    return _messageController.text.trim().isNotEmpty && !_isLoading;
  }

  void _sendMessage() async {
    if (!_canSend()) return;

    final message = _messageController.text.trim();
    _messageController.clear();
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Mock sending - just simulate delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        SnackBarHelper.showTopSnackBar(
          context,
          S.of(context)!.messageSent(message),
          backgroundColor: Colors.green,
        );
      }
    } catch (error) {
      if (mounted) {
        SnackBarHelper.showTopSnackBar(
          context,
          S.of(context)!.failedSendMessage(error.toString()),
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}