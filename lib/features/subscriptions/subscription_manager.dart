import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/subscriptions/subscription.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_type.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';

/// Manages Nostr subscriptions across different parts of the application.
///
/// This class provides a centralized way to handle subscriptions to Nostr events,
/// supporting different subscription types (chat, orders) and automatically
/// managing subscriptions based on session changes in the SessionNotifier.
class SubscriptionManager {
  final Ref ref;
  final Map<SubscriptionType, Subscription> _subscriptions = {};
  final _logger = Logger();
  ProviderSubscription? _sessionListener;

  // Controllers for each subscription type to expose streams to consumers
  final _ordersController = StreamController<NostrEvent>.broadcast();
  final _chatController = StreamController<NostrEvent>.broadcast();

  // Public streams that consumers can listen to
  Stream<NostrEvent> get orders => _ordersController.stream;
  Stream<NostrEvent> get chat => _chatController.stream;

  SubscriptionManager(this.ref) {
    _initSessionListener();
  }

  /// Initialize the session listener to automatically update subscriptions
  /// when sessions change in the SessionNotifier
  void _initSessionListener() {
    _sessionListener = ref.listen<List<Session>>(
      sessionNotifierProvider,
      (previous, current) {
        _logger.i('Sessions changed, updating subscriptions');
        _updateAllSubscriptions(current);
      },
      onError: (error, stackTrace) {
        _logger.e('Error in session listener',
            error: error, stackTrace: stackTrace);
      },
    );

    // Initialize subscriptions with current sessions
    final currentSessions = ref.read(sessionNotifierProvider);
    _updateAllSubscriptions(currentSessions);
  }

  /// Update all subscription types based on the current sessions
  void _updateAllSubscriptions(List<Session> sessions) {
    if (sessions.isEmpty) {
      _logger.i('No sessions available, clearing all subscriptions');
      _clearAllSubscriptions();
      return;
    }

    // Update each subscription type
    for (final type in SubscriptionType.values) {
      _updateSubscription(type, sessions);
    }
  }

  /// Clear all active subscriptions
  void _clearAllSubscriptions() {
    for (final type in SubscriptionType.values) {
      unsubscribeByType(type);
    }
  }

  /// Update a specific subscription type with the current sessions
  void _updateSubscription(SubscriptionType type, List<Session> sessions) {
    // Cancel existing subscriptions for this type
    unsubscribeByType(type);

    if (sessions.isEmpty) {
      _logger.i('No sessions for $type subscription');
      return;
    }

    try {
      final filter = _createFilterForType(type, sessions);

      // Create a subscription for this type
      subscribe(
        type: type,
        filter: filter,
      );

      _logger
          .i('Subscription created for $type with ${sessions.length} sessions');
    } catch (e, stackTrace) {
      _logger.e('Failed to create $type subscription',
          error: e, stackTrace: stackTrace);
    }
    _logger.i('Updated $type subscription with $_subscriptions');
  }

  /// Create a NostrFilter based on the subscription type and sessions
  NostrFilter _createFilterForType(
      SubscriptionType type, List<Session> sessions) {
    switch (type) {
      case SubscriptionType.orders:
        return NostrFilter(
          kinds: [1059],
          p: sessions.map((s) => s.tradeKey.public).toList(),
        );
      case SubscriptionType.chat:
        return NostrFilter(
          kinds: [1059],
          p: sessions
              .where((s) => s.peer?.publicKey != null)
              .map((s) => s.sharedKey?.public)
              .whereType<String>()
              .toList(),
        );
    }
  }

  /// Handle incoming events based on their subscription type
  void _handleEvent(SubscriptionType type, NostrEvent event) {
    try {
      switch (type) {
        case SubscriptionType.orders:
          _ordersController.add(event);
          break;
        case SubscriptionType.chat:
          _chatController.add(event);
          break;
      }
    } catch (e, stackTrace) {
      _logger.e('Error handling $type event', error: e, stackTrace: stackTrace);
    }
  }

  /// Subscribe to Nostr events with a specific filter and subscription type.
  Stream<NostrEvent> subscribe({
    required SubscriptionType type,
    required NostrFilter filter,
  }) {
    final nostrService = ref.read(nostrServiceProvider);

    final request = NostrRequest(
      filters: [filter],
    );

    final stream = nostrService.subscribeToEvents(request);
    final streamSubscription = stream.listen(
      (event) => _handleEvent(type, event),
      onError: (error, stackTrace) {
        _logger.e('Error in $type subscription',
            error: error, stackTrace: stackTrace);
      },
      cancelOnError: false,
    );

    final subscription = Subscription(
      request: request,
      streamSubscription: streamSubscription,
      onCancel: () {
        ref.read(nostrServiceProvider).unsubscribe(request.subscriptionId!);
      },
    );

    if (_subscriptions.containsKey(type)) {
      _subscriptions[type]!.cancel();
    }

    _subscriptions[type] = subscription;

    switch (type) {
      case SubscriptionType.orders:
        return orders;
      case SubscriptionType.chat:
        return chat;
    }
  }

  /// Subscribe to Nostr events for a specific session.
  Stream<NostrEvent> subscribeSession({
    required SubscriptionType type,
    required Session session,
    required NostrFilter Function(Session) createFilter,
  }) {
    final filter = createFilter(session);
    return subscribe(
      type: type,
      filter: filter,
    );
  }

  /// Unsubscribe from a specific subscription by ID.
  void unsubscribeById(SubscriptionType type) {
    final subscription = _subscriptions[type];
    if (subscription != null) {
      subscription.cancel();
      _subscriptions.remove(type);
      _logger.d('Canceled subscription for $type');
    }
  }

  /// Unsubscribe from all subscriptions of a specific type.
  void unsubscribeByType(SubscriptionType type) {
    final subscription = _subscriptions[type];
    if (subscription != null) {
      subscription.cancel();
      _subscriptions.remove(type);
      _logger.d('Canceled all subscriptions for $type');
    }
  }

  /// Unsubscribe from a session-based subscription.
  void unsubscribeSession(SubscriptionType type) {
    unsubscribeByType(type);
  }

  /// Check if there's an active subscription of a specific type.
  bool hasActiveSubscription(SubscriptionType type) {
    return _subscriptions[type] != null;
  }

  /// Get all active filters for a specific subscription type
  /// Returns an empty list if no active subscriptions exist for the type
  List<NostrFilter> getActiveFilters(SubscriptionType type) {
    final subscription = _subscriptions[type];
    return subscription?.request.filters ?? [];
  }

  void subscribeAll() {
    unsubscribeAll();
    _logger.i('Subscribing to all subscriptions');
    final currentSessions = ref.read(sessionNotifierProvider);
    _updateAllSubscriptions(currentSessions);
  }

  /// Unsubscribe from all subscription types
  void unsubscribeAll() {
    _logger.i('Unsubscribing from all subscriptions');
    for (final type in SubscriptionType.values) {
      unsubscribeByType(type);
    }
  }

  /// Dispose all subscriptions and listeners
  void dispose() {
    _logger.i('Disposing SubscriptionManager');
    if (_sessionListener != null) {
      _sessionListener!.close();
      _sessionListener = null;
    }

    unsubscribeAll();

    _ordersController.close();
    _chatController.close();

    _logger.i('SubscriptionManager disposed');
  }
}
