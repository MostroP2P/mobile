import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/disputes/notifiers/dispute_chat_notifier.dart';
import 'package:mostro_mobile/data/models/dispute_chat.dart';
import 'package:mostro_mobile/generated/l10n.dart';

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
            S.of(context)!.disputeCommunication,
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
                return _buildWaitingForAdmin(context);
              }

              if (disputeChat.messages.isEmpty) {
                return _buildNoMessages(context, disputeChat);
              }

              return _buildChatMessages(context, disputeChat);
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) => _buildError(context, error),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingForAdmin(BuildContext context) {
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
            S.of(context)!.waitingAdminAssignment,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            S.of(context)!.adminAssignmentDescription,
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

  Widget _buildNoMessages(BuildContext context, DisputeChat disputeChat) {
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
            S.of(context)!.adminAssigned,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            S.of(context)!.adminAssignedDescription,
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

  Widget _buildChatMessages(BuildContext context, DisputeChat disputeChat) {
    final messages = disputeChat.sortedMessages;
    return SizedBox(
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AdminAndTokenHeader(disputeChat: disputeChat),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
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
                                isFromAdmin ? S.of(context)!.admin : S.of(context)!.you,
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

  Widget _buildError(BuildContext context, Object error) {
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
            S.of(context)!.errorLoadingChat,
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
            S.of(context)!.adminPubkey,
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
                        isVerified ? S.of(context)!.tokenVerified : S.of(context)!.awaitingTokenVerification,
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
                        S.of(context)!.askAdminQuoteToken,
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
