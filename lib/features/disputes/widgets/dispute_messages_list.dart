import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/dispute_chat.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_message_bubble.dart';
import 'package:mostro_mobile/features/disputes/widgets/dispute_info_card.dart';
import 'package:mostro_mobile/generated/l10n.dart';

/// Enum representing the type of item in the dispute messages list
enum _ListItemType { infoCard, message, chatClosed }

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
      child: messages.isEmpty
        ? _buildEmptyMessagesLayout(context)
        : CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Admin assignment notification (if applicable)
              SliverToBoxAdapter(
                child: _buildAdminAssignmentNotification(context),
              ),
              // Messages list with dispute info card as first item
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final itemInfo = _getItemType(index, messages);
                    
                    switch (itemInfo.type) {
                      case _ListItemType.infoCard:
                        return DisputeInfoCard(dispute: widget.disputeData);
                      
                      case _ListItemType.chatClosed:
                        return _buildChatClosedMessage(context);
                      
                      case _ListItemType.message:
                        final message = messages[itemInfo.messageIndex!];
                        return DisputeMessageBubble(
                          message: message.message,
                          isFromUser: message.isFromUser,
                          timestamp: message.timestamp,
                          adminPubkey: message.adminPubkey,
                        );
                    }
                  },
                  childCount: _getItemCount(messages),
                ),
              ),
            ],
          ),
    );
  }

  /// Determine the type of item at the given index
  /// Returns a record with the item type and optional message index
  ({_ListItemType type, int? messageIndex}) _getItemType(int index, List<DisputeChat> messages) {
    if (index == 0) {
      return (type: _ListItemType.infoCard, messageIndex: null);
    }
    
    final messageIndex = index - 1;
    
    if (messageIndex >= messages.length) {
      // Beyond messages, must be chat closed (only added for resolved)
      return (type: _ListItemType.chatClosed, messageIndex: null);
    }
    
    return (type: _ListItemType.message, messageIndex: messageIndex);
  }

  /// Build layout for when there are no messages - with scrolling support
  Widget _buildEmptyMessagesLayout(BuildContext context) {
    final isResolvedStatus = _isResolvedStatus(widget.status);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: _scrollController,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // Admin assignment notification (if applicable)
                  _buildAdminAssignmentNotification(context),
                  
                  // Dispute info card
                  DisputeInfoCard(dispute: widget.disputeData),
                  
                  // Content area
                  _buildEmptyAreaContent(context),
                  
                  // Spacer for better layout
                  if (isResolvedStatus)
                    const Spacer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWaitingForAdmin(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            S.of(context)!.waitingAdminAssignment,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            S.of(context)!.waitingAdminDescription,
            style: TextStyle(
              color: AppTheme.textInactive,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChatArea(BuildContext context) {
    // Empty chat area for when admin is assigned but no messages yet
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        S.of(context)!.noMessagesYet,
        style: TextStyle(
          color: AppTheme.textInactive,
          fontSize: 16,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildAdminAssignmentNotification(BuildContext context) {
    // Only show admin assignment notification for 'in-progress' status
    // Don't show for 'initiated' (no admin yet) or 'resolved' (dispute finished)
    final normalizedStatus = _normalizeStatus(widget.status);
    if (normalizedStatus != 'in-progress') {
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
              S.of(context)!.adminAssigned,
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


  List<DisputeChat> _getMockMessages() {
    // For now, return empty list for real implementation
    // In the future, this should load real dispute chat messages
    // from the dispute chat provider or repository
    
    // Always return empty list - no mock messages should appear
    // Mock messages were causing confusion in the UI
    return [];
  }

  /// Normalizes status string by trimming, lowercasing, and replacing spaces/underscores with hyphens
  String _normalizeStatus(String status) {
    if (status.isEmpty) return '';
    // Trim, lowercase, and replace spaces/underscores with hyphens
    return status.trim().toLowerCase().replaceAll(RegExp(r'[\s_]+'), '-');
  }

  /// Checks if the status represents a resolved/terminal dispute state
  bool _isResolvedStatus(String status) {
    final normalizedStatus = _normalizeStatus(status);
    // Terminal states: resolved, closed, solved, seller-refunded
    return normalizedStatus == 'resolved' || 
           normalizedStatus == 'closed' || 
           normalizedStatus == 'solved' || 
           normalizedStatus == 'seller-refunded';
  }

  /// Build content for empty message area based on status
  Widget _buildEmptyAreaContent(BuildContext context) {
    final normalizedStatus = _normalizeStatus(widget.status);
    
    if (normalizedStatus == 'initiated') {
      return _buildWaitingForAdmin(context);
    } else if (_isResolvedStatus(widget.status)) {
      return _buildChatClosedArea(context);
    } else {
      // in-progress or other status
      return _buildEmptyChatArea(context);
    }
  }

  /// Get the total item count for ListView (info card + messages + chat closed message if needed)
  int _getItemCount(List<DisputeChat> messages) {
    int count = 1; // Always include info card
    count += messages.length; // Add messages
    
    // Add chat closed message for resolved disputes
    if (_isResolvedStatus(widget.status)) {
      count += 1;
    }
    
    return count;
  }

  /// Build chat closed area for when there are no messages but dispute is resolved
  Widget _buildChatClosedArea(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            S.of(context)!.noMessagesYet,
            style: TextStyle(
              color: AppTheme.textInactive,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _buildChatClosedMessage(context),
        ],
      ),
    );
  }

  /// Build message indicating that chat is closed for resolved disputes
  Widget _buildChatClosedMessage(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dark1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[700]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            color: Colors.grey[400],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.disputeChatClosed,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}