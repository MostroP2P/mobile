import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/data/models/dispute_chat.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/disputes/providers/dispute_providers.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

/// Provider for dispute chat notifier
final disputeChatProvider = StateNotifierProvider.autoDispose.family<DisputeChatNotifier, AsyncValue<DisputeChat?>, String>((ref, disputeId) {
  return DisputeChatNotifier(disputeId, ref);
});

/// Notifier for managing dispute chat communication
class DisputeChatNotifier extends StateNotifier<AsyncValue<DisputeChat?>> {
  final String disputeId;
  final Ref _ref;
  final Logger _logger = Logger();
  
  StreamSubscription<NostrEvent>? _chatSubscription;
  StreamSubscription<NostrEvent>? _disputeSubscription;
  bool _isInitializing = false;

  DisputeChatNotifier(this.disputeId, this._ref) : super(const AsyncValue.loading()) {
    _initialize();
  }

  /// Initialize the dispute chat
  Future<void> _initialize() async {
    // Prevent concurrent initialization
    if (_isInitializing) {
      _logger.i('Initialization already in progress for dispute: $disputeId');
      return;
    }
    
    _isInitializing = true;
    
    try {
      _logger.i('Initializing dispute chat for dispute: $disputeId');
      
      // Cancel any existing subscriptions first
      await _cancelSubscriptions();
      
      // Get dispute details first
      final disputeDetails = await _ref.read(disputeDetailsProvider(disputeId).future);
      
      if (disputeDetails == null) {
        state = const AsyncValue.data(null);
        return;
      }

      // Check if admin is assigned
      if (disputeDetails.hasAdmin) {
        _logger.i('Admin assigned to dispute: ${disputeDetails.adminPubkey}');
        
        // Get user pubkey from session (find session for this dispute's order)
        final sessions = _ref.read(sessionNotifierProvider);
        final userSession = sessions.firstWhereOrNull((s) => s.orderId == disputeDetails.orderId);
        final userPubkey = userSession?.tradeKey.public ?? '';
        
        // Create dispute chat with admin info
        final disputeChat = DisputeChat(
          disputeId: disputeId,
          adminPubkey: disputeDetails.adminPubkey!,
          userPubkey: userPubkey,
          disputeToken: disputeDetails.disputeToken,
          messages: [],
        );
        
        state = AsyncValue.data(disputeChat);
        
        // Cancel dispute events subscription since we now have an admin
        try {
          if (_disputeSubscription != null) {
            _logger.i('Cancelling dispute events subscription since admin is assigned');
            await _disputeSubscription?.cancel();
            _disputeSubscription = null;
          }
        } catch (error) {
          _logger.e('Error cancelling dispute subscription: $error');
          // Continue with chat subscription even if cancellation fails
        }
        
        // Subscribe to chat messages
        await _subscribeToChatMessages();
      } else {
        _logger.i('No admin assigned yet, waiting...');
        state = const AsyncValue.data(null);
        
        // Subscribe to dispute events to detect admin assignment
        await _subscribeToDisputeEvents();
      }
    } catch (error, stackTrace) {
      _logger.e('Error initializing dispute chat: $error');
      state = AsyncValue.error(error, stackTrace);
    } finally {
      _isInitializing = false;
    }
  }
  
  /// Cancel any existing subscriptions
  Future<void> _cancelSubscriptions() async {
    try {
      if (_chatSubscription != null) {
        _logger.i('Cancelling existing chat subscription');
        await _chatSubscription?.cancel();
        _chatSubscription = null;
      }
      
      if (_disputeSubscription != null) {
        _logger.i('Cancelling existing dispute subscription');
        await _disputeSubscription?.cancel();
        _disputeSubscription = null;
      }
    } catch (error) {
      _logger.e('Error cancelling subscriptions: $error');
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
        p: [currentState.userPubkey], // Messages intended for this user
        since: DateTime.now().subtract(const Duration(days: 7)), // Last 7 days
      );

      final request = NostrRequest(
        filters: [filter],
        subscriptionId: 'dispute-chat-$disputeId-${DateTime.now().millisecondsSinceEpoch}',
      );

      _logger.i('Subscribing to dispute chat messages with ID: ${request.subscriptionId}');
      
      final stream = nostrService.subscribeToEvents(request);
      _chatSubscription = stream.listen(
        _handleChatMessage,
        onError: (error) {
          _logger.e('Error in chat message subscription: $error');
        },
      );
    } catch (error) {
      _logger.e('Error subscribing to chat messages: $error');
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
          'd': [disputeId], // Filter by dispute ID
        },
        since: DateTime.now(),
      );

      final request = NostrRequest(
        filters: [filter],
        subscriptionId: 'dispute-events-$disputeId-${DateTime.now().millisecondsSinceEpoch}',
      );

      _logger.i('Subscribing to dispute events with ID: ${request.subscriptionId}');
      
      final stream = nostrService.subscribeToEvents(request);
      _disputeSubscription = stream.listen(
        _handleDisputeEvent,
        onError: (error) {
          _logger.e('Error in dispute event subscription: $error');
        },
      );
    } catch (error) {
      _logger.e('Error subscribing to dispute events: $error');
    }
  }

  /// Handle incoming chat messages
  void _handleChatMessage(NostrEvent event) {
    try {
      _logger.i('Received chat message for dispute: $disputeId');
      
      final currentState = state.value;
      if (currentState == null) return;

      // TODO: Decrypt gift wrap message
      // For now, we'll add the raw event to messages
      final updatedMessages = [...currentState.messages, event];
      
      final updatedChat = currentState.copyWith(messages: updatedMessages);
      state = AsyncValue.data(updatedChat);
      
      _logger.i('Added message to dispute chat, total messages: ${updatedMessages.length}');
    } catch (error) {
      _logger.e('Error handling chat message: $error');
    }
  }

  /// Handle dispute events (e.g., admin assignment)
  void _handleDisputeEvent(NostrEvent event) {
    try {
      _logger.i('Received dispute event for dispute: $disputeId');
      
      // TODO: Parse dispute event and check for admin assignment
      // If admin is assigned, initialize chat
      
      // For now, we'll refresh the dispute details
      _ref.invalidate(disputeDetailsProvider(disputeId));
      _initialize();
    } catch (error) {
      _logger.e('Error handling dispute event: $error');
    }
  }

  /// Send a message to the admin using NIP-17 encryption
  Future<void> sendMessage(String content) async {
    try {
      final currentState = state.value;
      if (currentState == null) {
        throw Exception('No admin assigned to dispute');
      }

      if (currentState.userPubkey.isEmpty) {
        throw Exception('User pubkey not available');
      }

      _logger.i('Sending message to admin for dispute: $disputeId');
      
      // Get user's trade key from session
      final sessions = _ref.read(sessionNotifierProvider);
      final disputeDetails = await _ref.read(disputeDetailsProvider(disputeId).future);
      
      if (disputeDetails == null) {
        throw Exception('Dispute details not available');
      }
      
      final userSession = sessions.firstWhereOrNull((s) => s.orderId == disputeDetails.orderId);
      if (userSession == null) {
        throw Exception('User session not found for dispute');
      }

      // Create the inner message event (kind 14 for NIP-17 chat)
      final innerMessage = NostrEvent.fromPartialData(
        keyPairs: userSession.tradeKey,
        content: content,
        kind: 14, // NIP-17 chat message kind
        tags: [
          ['p', currentState.adminPubkey], // Recipient (admin)
        ],
      );

      // Add to local state immediately for optimistic UI update
      final updatedMessages = [...currentState.messages, innerMessage];
      final updatedChat = currentState.copyWith(
        messages: updatedMessages,
        lastMessageAt: DateTime.now(),
      );
      state = AsyncValue.data(updatedChat);

      // Compute shared key between user's trade key and admin's public key
      final sharedKey = NostrUtils.computeSharedKey(
        userSession.tradeKey.private,
        currentState.adminPubkey,
      );

      try {
        // Wrap the message using NIP-17 encryption
        final wrappedEvent = await innerMessage.mostroWrap(sharedKey);
        
        // Send to network
        final nostrService = _ref.read(nostrServiceProvider);
        await nostrService.publishEvent(wrappedEvent);
        
        _logger.i('Message successfully sent to admin via NIP-17');
      } catch (networkError) {
        _logger.e('Failed to send message to network: $networkError');
        
        // Remove from local state if network send failed
        final revertedMessages = currentState.messages;
        final revertedChat = currentState.copyWith(messages: revertedMessages);
        state = AsyncValue.data(revertedChat);
        
        rethrow;
      }
    } catch (error) {
      _logger.e('Error sending message: $error');
      rethrow;
    }
  }

  @override
  void dispose() {
    _logger.i('Disposing dispute chat notifier for dispute: $disputeId');
    _chatSubscription?.cancel();
    _disputeSubscription?.cancel();
    super.dispose();
  }
}
