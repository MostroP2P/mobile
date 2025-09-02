import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/dispute_chat.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_message_bubble.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_info_card.dart';
import 'package:mostro_mobile/features/disputes/data/dispute_mock_data.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class DisputeMessagesList extends StatefulWidget {
  final String disputeId;
  final String status;
  final DisputeData disputeData;
  final ScrollController? scrollController;

  const DisputeMessagesList({
    super.key,
    required this.disputeId,
    required this.status,
    required this.disputeData,
    this.scrollController,
  });

  @override
  State<DisputeMessagesList> createState() => _DisputeMessagesListState();
}

class _DisputeMessagesListState extends State<DisputeMessagesList> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    
    // Scroll to bottom on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animate: false);
    });
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    
    if (animate) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Generate mock messages based on status
    final messages = _getMockMessages();
    
    return Container(
      color: AppTheme.backgroundDark,
      child: Column(
        children: [
          // Admin assignment notification (if applicable)
          _buildAdminAssignmentNotification(context),
          
          // Messages list with info card at top (scrolleable)
          Expanded(
            child: messages.isEmpty 
              ? Column(
                  children: [
                    DisputeInfoCard(dispute: widget.disputeData),
                    Expanded(child: _buildWaitingForAdmin(context)),
                  ],
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length + 1, // +1 for info card
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // First item is the dispute info card
                      return DisputeInfoCard(dispute: widget.disputeData);
                    }
                    
                    // Rest are messages (adjust index)
                    final message = messages[index - 1];
                    return DisputeMessageBubble(
                      message: message.message,
                      isFromUser: message.isFromUser,
                      timestamp: message.timestamp,
                      adminPubkey: message.adminPubkey,
                    );
                  },
                ),
          ),
          
          // Resolution notification (if resolved)
          if (widget.status == 'resolved')
            _buildResolutionNotification(context),
        ],
      ),
    );
  }

  Widget _buildWaitingForAdmin(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              S.of(context)?.waitingAdminAssignment ?? 'Waiting for admin assignment',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context)?.waitingAdminDescription ?? 'Your dispute has been submitted. An admin will be assigned to help resolve this issue.',
              style: TextStyle(
                color: AppTheme.textInactive,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminAssignmentNotification(BuildContext context) {
    // Only show admin assignment notification if not in initiated state
    if (widget.status == 'initiated') {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.admin_panel_settings,
            color: Colors.blue[300],
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              S.of(context)?.adminAssigned ?? 'Admin has been assigned to this dispute',
              style: TextStyle(
                color: Colors.blue[300],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionNotification(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green[300],
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              S.of(context)?.disputeResolvedMessage ?? 'This dispute has been resolved. Check your wallet for any refunds or payments.',
              style: TextStyle(
                color: Colors.green[300],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DisputeChat> _getMockMessages() {
    if (!DisputeMockData.isMockEnabled) {
      // TODO: Load real messages here when mock is disabled
      return [];
    }
    
    // Use mock data from the centralized mock file
    return DisputeMockData.getMockMessages(widget.disputeId, widget.status);
  }
}