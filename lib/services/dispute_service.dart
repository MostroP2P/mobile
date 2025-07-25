import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:nostr/nostr.dart';

import '../data/models/dispute.dart';
import '../data/models/dispute_event.dart';
import '../data/models/enums/action.dart' as mostro;
import '../data/models/mostro_message.dart';
import '../features/order/models/order_state.dart';
import '../features/order/providers/order_notifier_provider.dart';
import '../shared/providers/nostr_provider.dart';

/// Provider for the DisputeService
final disputeServiceProvider = Provider<DisputeService>((ref) {
  return DisputeService(ref);
});

/// Service responsible for handling dispute events and updating the app state
class DisputeService {
  final Ref _ref;
  final _logger = Logger('DisputeService');
  StreamSubscription<NostrEvent>? _disputeSubscription;
  
  DisputeService(this._ref) {
    // Initialize the dispute event subscription
    _subscribeToDisputeEvents();
  }

  /// Subscribes to dispute events (kind 38383) related to orders
  void _subscribeToDisputeEvents() {
    final relay = _ref.read(nostrRelayProvider);
    
    // Create a filter for dispute events (kind 38383)
    final filter = Filter(
      kinds: [38383],
      // We could add additional filters here if needed
      // e.g., specific tags for orders the user is involved in
    );
    
    _logger.info('Subscribing to dispute events');
    
    // Subscribe to dispute events
    _disputeSubscription = relay.subscribe(
      [filter],
      onEvent: _handleDisputeEvent,
      onError: (error) {
        _logger.severe('Error in dispute event subscription: $error');
      },
    );
  }

  /// Handles incoming dispute events
  void _handleDisputeEvent(NostrEvent event) {
    try {
      // Parse the dispute event
      final disputeEvent = DisputeEvent.fromNostrEvent(event);
      _logger.info('Received dispute event: ${disputeEvent.disputeId} with status: ${disputeEvent.status}');
      
      // Update the order state with the dispute information
      _updateOrderState(disputeEvent);
    } catch (e, stackTrace) {
      _logger.severe('Error handling dispute event', e, stackTrace);
    }
  }

  /// Updates the order state with dispute information
  void _updateOrderState(DisputeEvent disputeEvent) {
    // Get the order ID from the dispute event
    final orderId = disputeEvent.disputeId;
    
    if (orderId == null || orderId.isEmpty) {
      _logger.warning('Dispute event has no order ID');
      return;
    }
    
    // Check if the order notifier exists for this order
    final orderNotifierExists = _ref.exists(orderNotifierProvider(orderId));
    
    if (!orderNotifierExists) {
      _logger.info('No order notifier found for order $orderId');
      return;
    }
    
    // Get the current order state
    final orderState = _ref.read(orderNotifierProvider(orderId));
    
    // Create or update the dispute object
    final dispute = Dispute(
      disputeId: disputeEvent.disputeId ?? '',
      orderId: orderId,
      status: disputeEvent.status,
    );
    
    // Determine the appropriate action based on the dispute status
    mostro.Action action;
    
    switch (disputeEvent.status?.toLowerCase()) {
      case 'initiated':
        // Check if the current user initiated the dispute
        final isCurrentUserDisputer = disputeEvent.pubkey == _ref.read(nostrProvider).publicKey;
        action = isCurrentUserDisputer 
            ? mostro.Action.disputeInitiatedByYou 
            : mostro.Action.disputeInitiatedByPeer;
        break;
      case 'in-progress':
        action = mostro.Action.adminTookDispute;
        break;
      case 'resolved':
        action = mostro.Action.adminSettled;
        break;
      default:
        action = mostro.Action.dispute;
    }
    
    // Create a MostroMessage to update the order state
    final message = MostroMessage(
      action: action,
      id: orderId,
      payload: dispute,
    );
    
    // Update the order state
    _ref.read(orderNotifierProvider(orderId).notifier).updateState(message);
    
    _logger.info('Updated order state for order $orderId with dispute status: ${disputeEvent.status}');
  }

  /// Dispose of subscriptions when the service is no longer needed
  void dispose() {
    _disputeSubscription?.cancel();
    _logger.info('Disposed dispute service');
  }
}
