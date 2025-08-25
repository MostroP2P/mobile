import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/disputes/notifiers/dispute_chat_notifier.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class DisputeInputSection extends ConsumerStatefulWidget {
  final String disputeId;

  const DisputeInputSection({
    super.key,
    required this.disputeId,
  });

  @override
  ConsumerState<DisputeInputSection> createState() => _DisputeInputSectionState();
}

class _DisputeInputSectionState extends ConsumerState<DisputeInputSection> {
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final notifier = ref.read(disputeChatProvider(widget.disputeId).notifier);
      await notifier.sendMessage(message);
      _messageController.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context)!.failedSendMessage(error.toString())),
            backgroundColor: AppTheme.red1,
          ),
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

  @override
  Widget build(BuildContext context) {
    final disputeChatAsync = ref.watch(disputeChatProvider(widget.disputeId));

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1.0,
          ),
        ),
      ),
      child: disputeChatAsync.when(
        data: (disputeChat) {
          // Only show input if admin is assigned
          if (disputeChat == null) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                S.of(context)!.waitingAdminAssignmentInput,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }

          return Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isLoading,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: S.of(context)!.typeYourMessage,
                      hintStyle: TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.dark2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.mostroGreen,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isLoading ? null : _sendMessage,
                    icon: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.backgroundDark,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.send,
                            color: AppTheme.backgroundDark,
                          ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => Container(
          padding: const EdgeInsets.all(16),
          child: const Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => Container(
          padding: const EdgeInsets.all(16),
          child: Text(
            S.of(context)!.errorLoadingChat,
            style: TextStyle(
              color: AppTheme.red1,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
