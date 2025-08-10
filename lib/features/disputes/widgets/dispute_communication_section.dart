import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/disputes/notifiers/dispute_chat_notifier.dart';
import 'package:mostro_mobile/data/models/dispute_chat.dart';

class DisputeCommunicationSection extends ConsumerWidget {
  final String disputeId;

  const DisputeCommunicationSection({
    super.key,
    required this.disputeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputeChatAsync = ref.watch(disputeChatProvider(disputeId));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Communication',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          disputeChatAsync.when(
            data: (disputeChat) {
              if (disputeChat == null) {
                return _buildWaitingForAdmin();
              }

              if (disputeChat.messages.isEmpty) {
                return _buildNoMessages(disputeChat);
              }

              return _buildChatMessages(disputeChat);
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) => _buildError(error),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingForAdmin() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dark1,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.hourglass_empty,
            color: AppTheme.textSecondary,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            'Waiting for admin assignment',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'An admin will be assigned to your dispute soon. Once assigned, you can communicate directly with them here.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoMessages(disputeChat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dark1,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _AdminAndTokenHeader(disputeChat: disputeChat),
          const SizedBox(height: 12),
          Icon(
            Icons.chat_bubble_outline,
            color: AppTheme.textSecondary,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            'Admin assigned',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You can now communicate with the admin. Start the conversation by sending a message below.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          // token shown in header above
        ],
      ),
    );
  }

  Widget _buildChatMessages(disputeChat) {
    final messages = disputeChat.sortedMessages;
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AdminAndTokenHeader(disputeChat: disputeChat),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isFromAdmin = message.pubkey == disputeChat.adminPubkey;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: isFromAdmin 
                      ? MainAxisAlignment.start 
                      : MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isFromAdmin 
                              ? AppTheme.dark2 
                              : AppTheme.mostroGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.content ?? '',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isFromAdmin ? 'Admin' : 'You',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.red1.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: AppTheme.red1,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            'Error loading chat',
            style: TextStyle(
              color: AppTheme.red1,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AdminAndTokenHeader extends StatelessWidget {
  final DisputeChat disputeChat;
  const _AdminAndTokenHeader({required this.disputeChat});

  @override
  Widget build(BuildContext context) {
    final hasToken = (disputeChat.disputeToken?.isNotEmpty ?? false);
    final isVerified = disputeChat.isTokenVerified == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dark2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin pubkey',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          SelectableText(
            disputeChat.adminPubkey,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white),
          ),
          if (hasToken) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isVerified ? AppTheme.mostroGreen : Colors.amber).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isVerified ? Icons.verified : Icons.security, size: 14, color: isVerified ? AppTheme.mostroGreen : Colors.amber),
                      const SizedBox(width: 6),
                      Text(
                        isVerified ? 'Token verified' : 'Awaiting token verification',
                        style: TextStyle(color: isVerified ? AppTheme.mostroGreen : Colors.amber, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ask admin to quote this token:',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      SelectableText(
                        disputeChat.disputeToken!,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
