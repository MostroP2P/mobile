import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/data/models/dispute_chat.dart';
import 'package:mostro_mobile/features/disputes/providers/dispute_providers.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';

/// Provider for dispute chat notifier
final disputeChatProvider = StateNotifierProvider.family<DisputeChatNotifier, AsyncValue<DisputeChat?>, String>((ref, disputeId) {
  return DisputeChatNotifier(disputeId, ref);
});

/// Notifier for managing dispute chat communication
class DisputeChatNotifier extends StateNotifier<AsyncValue<DisputeChat?>> {
  final String disputeId;
  final Ref _ref;
  final Logger _logger = Logger('DisputeChatNotifier');
  
  StreamSubscription<NostrEvent>? _chatSubscription;
  StreamSubscription<NostrEvent>? _disputeSubscription;

  DisputeChatNotifier(this.disputeId, this._ref) : super(const AsyncValue.loading()) {
    _initialize();
  }

  /// Initialize the dispute chat
  Future<void> _initialize() async {
    try {
      _logger.info('Initializing dispute chat for dispute: $disputeId');
      
      // Get dispute details first
      final disputeDetails = await _ref.read(disputeDetailsProvider(disputeId).future);
      
      if (disputeDetails == null) {
        state = const AsyncValue.data(null);
        return;
      }

      // Check if admin is assigned
      if (disputeDetails.hasAdmin) {
        _logger.info('Admin assigned to dispute: ${disputeDetails.adminPubkey}');
        
        // Create dispute chat with admin info
        final disputeChat = DisputeChat(
          disputeId: disputeId,
          adminPubkey: disputeDetails.adminPubkey!,
          userPubkey: '', // TODO: Get user pubkey from session/settings
          disputeToken: disputeDetails.disputeToken,
          messages: [],
        );
        
        state = AsyncValue.data(disputeChat);
        
        // Subscribe to chat messages
        await _subscribeToChatMessages();
      } else {
        _logger.info('No admin assigned yet, waiting...');
        state = const AsyncValue.data(null);
        
        // Subscribe to dispute events to detect admin assignment
        await _subscribeToDisputeEvents();
      }
    } catch (error, stackTrace) {
      _logger.severe('Error initializing dispute chat: $error', error, stackTrace);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Subscribe to chat messages between user and admin
  Future<void> _subscribeToChatMessages() async {
    try {
      final currentState = state.value;
      if (currentState == null) return;

      final nostrService = _ref.read(nostrServiceProvider);
      
      // Create filter for gift wrap messages between user and admin
      final filter = NostrFilter(
        kinds: [1059], // Gift wrap messages
        authors: [currentState.adminPubkey], // Messages from admin
        since: DateTime.now().subtract(const Duration(days: 7)), // Last 7 days
      );

      final request = NostrRequest(
        filters: [filter],
        subscriptionId: 'dispute-chat-$disputeId-${DateTime.now().millisecondsSinceEpoch}',
      );

      _logger.info('Subscribing to dispute chat messages with ID: ${request.subscriptionId}');
      
      final stream = nostrService.subscribeToEvents(request);
      _chatSubscription = stream.listen(
        _handleChatMessage,
        onError: (error) {
          _logger.severe('Error in chat message subscription: $error');
        },
      );
    } catch (error) {
      _logger.severe('Error subscribing to chat messages: $error');
    }
  }

  /// Subscribe to dispute events to detect admin assignment
  Future<void> _subscribeToDisputeEvents() async {
    try {
      final nostrService = _ref.read(nostrServiceProvider);
      
      // Create filter for dispute events related to this dispute
      final filter = NostrFilter(
        kinds: [38383], // Dispute events
        additionalFilters: {
          '#d': [disputeId], // Filter by dispute ID
        },
        since: DateTime.now(),
      );

      final request = NostrRequest(
        filters: [filter],
        subscriptionId: 'dispute-events-$disputeId-${DateTime.now().millisecondsSinceEpoch}',
      );

      _logger.info('Subscribing to dispute events with ID: ${request.subscriptionId}');
      
      final stream = nostrService.subscribeToEvents(request);
      _disputeSubscription = stream.listen(
        _handleDisputeEvent,
        onError: (error) {
          _logger.severe('Error in dispute event subscription: $error');
        },
      );
    } catch (error) {
      _logger.severe('Error subscribing to dispute events: $error');
    }
  }

  /// Handle incoming chat messages
  void _handleChatMessage(NostrEvent event) {
    try {
      _logger.info('Received chat message for dispute: $disputeId');
      
      final currentState = state.value;
      if (currentState == null) return;

      // TODO: Decrypt gift wrap message
      // For now, we'll add the raw event to messages
      final updatedMessages = [...currentState.messages, event];
      
      final updatedChat = currentState.copyWith(messages: updatedMessages);
      state = AsyncValue.data(updatedChat);
      
      _logger.info('Added message to dispute chat, total messages: ${updatedMessages.length}');
    } catch (error) {
      _logger.severe('Error handling chat message: $error');
    }
  }

  /// Handle dispute events (e.g., admin assignment)
  void _handleDisputeEvent(NostrEvent event) {
    try {
      _logger.info('Received dispute event for dispute: $disputeId');
      
      // TODO: Parse dispute event and check for admin assignment
      // If admin is assigned, initialize chat
      
      // For now, we'll refresh the dispute details
      _ref.invalidate(disputeDetailsProvider(disputeId));
      _initialize();
    } catch (error) {
      _logger.severe('Error handling dispute event: $error');
    }
  }

  /// Send a message to the admin
  Future<void> sendMessage(String content) async {
    try {
      final currentState = state.value;
      if (currentState == null) {
        throw Exception('No admin assigned to dispute');
      }

      _logger.info('Sending message to admin for dispute: $disputeId');
      
      // TODO: Implement actual gift wrap message sending
      // For now, we'll add it to local messages as a placeholder
      final userMessage = NostrEvent(
        id: '', // Will be generated
        pubkey: currentState.userPubkey,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        kind: 1,
        tags: [
          ['d', disputeId], // Dispute ID tag
        ],
        content: content,
        sig: '', // Will be generated when signing
      );

      final updatedMessages = [...currentState.messages, userMessage];
      final updatedChat = currentState.copyWith(messages: updatedMessages);
      state = AsyncValue.data(updatedChat);
      
      _logger.info('Message sent and added to local chat');
    } catch (error) {
      _logger.severe('Error sending message: $error');
      rethrow;
    }
  }

  @override
  void dispose() {
    _logger.info('Disposing dispute chat notifier for dispute: $disputeId');
    _chatSubscription?.cancel();
    _disputeSubscription?.cancel();
    super.dispose();
  }
}
