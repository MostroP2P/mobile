import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:dart_nostr/dart_nostr.dart';

import '../data/models/dispute.dart';
import '../data/models/dispute_event.dart';
import '../data/models/enums/action.dart' as mostro;
import '../data/models/mostro_message.dart';
import '../features/order/providers/order_notifier_provider.dart';
import '../shared/providers/nostr_service_provider.dart';

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
    final nostrService = _ref.read(nostrServiceProvider);

    // Create a filter for dispute events (kind 38383)
    final filter = NostrFilter(
      kinds: [38383],
      // Add tag filter for dispute events (z tag with value 'dispute')
      additionalFilters: {
        '#z': ['dispute'],
      },
    );

    _logger.info('Subscribing to dispute events (kind 38383)');

    // Create a NostrRequest with the filter
    final request = NostrRequest(
      filters: [filter],
      subscriptionId: 'dispute-events-${DateTime.now().millisecondsSinceEpoch}',
    );

    // Subscribe to dispute events using the stream API
    final stream = nostrService.subscribeToEvents(request);
    _disputeSubscription = stream.listen(
      _handleDisputeEvent,
      onError: (error) {
        _logger.severe('Error in dispute event subscription: $error');
      },
    );

    _logger.info(
        'Subscribed to dispute events with ID: ${request.subscriptionId}');
  }

  /// Handles incoming dispute events
  void _handleDisputeEvent(NostrEvent event) {
    try {
      // Parse the dispute event
      final disputeEvent = DisputeEvent.fromEvent(event);
      _logger.info(
          'Received dispute event: ${disputeEvent.disputeId} with status: ${disputeEvent.status}');

      // Update the order state with the dispute information
      _updateOrderState(disputeEvent);
    } catch (e, stackTrace) {
      _logger.severe('Error handling dispute event: $e', e, stackTrace);
    }
  }

  /// Updates the order state with dispute information
  void _updateOrderState(DisputeEvent disputeEvent) {
    // Get the dispute ID from the event
    final disputeId = disputeEvent.disputeId;

    if (disputeId.isEmpty) {
      _logger.warning('Dispute event has no dispute ID');
      return;
    }

    // In Mostro's implementation, the dispute ID is the order ID
    final orderId = disputeId;

    // Check if the order notifier exists for this order
    final orderNotifierExists = _ref.exists(orderNotifierProvider(orderId));

    if (!orderNotifierExists) {
      _logger.info('No order notifier found for order $orderId');
      return;
    }

    // Create or update the dispute object
    final dispute = Dispute(
      disputeId: disputeId,
      orderId: orderId,
      status: disputeEvent.status,
    );

    // Determine the appropriate action based on the dispute status
    mostro.Action action;

    switch (disputeEvent.status.toLowerCase()) {
      case 'initiated':
        // For initiated disputes, we need to check if the current user initiated it
        // We can determine this by checking the current order state's action
        final orderState = _ref.read(orderNotifierProvider(orderId));

        // If the last action was dispute, then the current user initiated it
        if (orderState.action == mostro.Action.dispute) {
          action = mostro.Action.disputeInitiatedByYou;
          _logger.info('Dispute initiated by current user for order $orderId');
        } else {
          // Otherwise, it was initiated by the peer
          action = mostro.Action.disputeInitiatedByPeer;
          _logger.info('Dispute initiated by peer for order $orderId');
        }
        break;
      case 'in-progress':
        action = mostro.Action.adminTookDispute;
        _logger.info('Admin took dispute for order $orderId');
        break;
      case 'resolved':
        action = mostro.Action.adminSettled;
        _logger.info('Admin settled dispute for order $orderId');
        break;
      default:
        action = mostro.Action.dispute;
        _logger.info(
            'Unknown dispute status ${disputeEvent.status} for order $orderId');
    }

    // Create a MostroMessage to update the order state
    final message = MostroMessage(
      action: action,
      id: orderId,
      payload: dispute,
    );

    // Get the OrderNotifier and update its state
    final orderNotifier = _ref.read(orderNotifierProvider(orderId).notifier);

    // Update the state with the dispute message
    try {
      // Call handleEvent on the orderNotifier which will properly update the state
      if (orderNotifier.mounted) {
        orderNotifier.handleEvent(message);
        _logger.info(
            'Updated order state for order $orderId with dispute status: ${disputeEvent.status}');
      } else {
        _logger.warning(
            'OrderNotifier for $orderId is not mounted, could not update state');
      }
    } catch (e, stackTrace) {
      _logger.severe('Error updating order state: $e', e, stackTrace);
    }
  }

  /// Dispose of subscriptions when the service is no longer needed
  void dispose() {
    if (_disputeSubscription != null) {
      _disputeSubscription!.cancel();
      _logger.info('Canceled dispute event subscription');
    }
    _logger.info('Disposed dispute service');
  }
}
