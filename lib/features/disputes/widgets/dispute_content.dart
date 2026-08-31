import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_header.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_order_id.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_description.dart';
import 'package:mostro_mobile/features/disputes/notifiers/dispute_chat_notifier.dart';
import 'package:mostro_mobile/features/disputes/providers/dispute_read_status_provider.dart';
import 'package:mostro_mobile/data/models/dispute.dart';

/// Main content widget for dispute information
class DisputeContent extends ConsumerStatefulWidget {
  final DisputeData dispute;

  const DisputeContent({super.key, required this.dispute});

  @override
  ConsumerState<DisputeContent> createState() => _DisputeContentState();
}

class _DisputeContentState extends ConsumerState<DisputeContent> {
  /// Normalizes status string by trimming, lowercasing, and replacing spaces/underscores with hyphens
  String _normalizeStatus(String status) {
    if (status.isEmpty) return '';
    return status.trim().toLowerCase().replaceAll(RegExp(r'[\s_]+'), '-');
  }

  @override
  Widget build(BuildContext context) {
    // Get the last message for in-progress disputes
    String descriptionText = widget.dispute.getLocalizedDescription(context);
    
    final normalizedStatus = _normalizeStatus(widget.dispute.status);
    if (normalizedStatus == 'in-progress') {
      // Try to get the last message from the chat
      final chatState = ref.watch(disputeChatNotifierProvider(widget.dispute.disputeId));
      final messages = chatState.messages;
      
      if (messages.isNotEmpty) {
        // Show the last message
        final lastMessage = messages.last;
        descriptionText = lastMessage.content;
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: DisputeHeader(dispute: widget.dispute),
            ),
            // Unread indicator for in-progress disputes. valueOrNull keeps
            // the previous value while the provider recomputes, so the dot
            // does not blink off for a frame on every chat emission.
            if (normalizedStatus == 'in-progress' &&
                (ref
                        .watch(
                            disputeHasUnreadProvider(widget.dispute.disputeId))
                        .valueOrNull ??
                    false))
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        DisputeOrderId(orderId: widget.dispute.orderIdDisplay),
        const SizedBox(height: 2),
        DisputeDescription(description: descriptionText),
      ],
    );
  }
}
