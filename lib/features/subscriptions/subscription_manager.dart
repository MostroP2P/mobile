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
  late final ProviderSubscription _sessionListener;

  final _ordersController = StreamController<NostrEvent>.broadcast();
  final _chatController = StreamController<NostrEvent>.broadcast();

  Stream<NostrEvent> get orders => _ordersController.stream;
  Stream<NostrEvent> get chat => _chatController.stream;

  SubscriptionManager(this.ref) {
    _initSessionListener();
  }

  void _initSessionListener() {
    _sessionListener = ref.listen<List<Session>>(
      sessionNotifierProvider,
      (previous, current) {
        _updateAllSubscriptions(current);
      },
      fireImmediately: true,
      onError: (error, stackTrace) {
        _logger.e('Error in session listener',
            error: error, stackTrace: stackTrace);
      },
    );
  }

  void _updateAllSubscriptions(List<Session> sessions) {
    if (sessions.isEmpty) {
      _logger.i('No sessions available, clearing all subscriptions');
      _clearAllSubscriptions();
      return;
    }

    for (final type in SubscriptionType.values) {
      _updateSubscription(type, sessions);
    }
  }

  void _clearAllSubscriptions() {
    for (final type in SubscriptionType.values) {
      unsubscribeByType(type);
    }
  }

  void _updateSubscription(SubscriptionType type, List<Session> sessions) {
    unsubscribeByType(type);

    if (sessions.isEmpty) {
      _logger.i('No sessions for $type subscription');
      return;
    }

    try {
      final filter = _createFilterForType(type, sessions);
      if (filter == null) {
        return;
      }
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
  }

  NostrFilter? _createFilterForType(
      SubscriptionType type, List<Session> sessions) {
    switch (type) {
      case SubscriptionType.orders:
        if (sessions.isEmpty) {
          return null;
        }
        return NostrFilter(
          kinds: [1059],
          p: sessions.map((s) => s.tradeKey.public).toList(),
        );
      case SubscriptionType.chat:
        if (sessions.isEmpty) {
          return null;
        }
        if (sessions.where((s) => s.sharedKey?.public != null).isEmpty) {
          return null;
        }
        return NostrFilter(
          kinds: [1059],
          p: sessions
              .where((s) => s.sharedKey?.public != null)
              .map((s) => s.sharedKey!.public)
              .toList(),
        );
    }
  }

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

  void unsubscribeByType(SubscriptionType type) {
    final subscription = _subscriptions[type];
    if (subscription != null) {
      subscription.cancel();
      _subscriptions.remove(type);
    }
  }

  void unsubscribeSession(SubscriptionType type) {
    unsubscribeByType(type);
  }

  bool hasActiveSubscription(SubscriptionType type) {
    return _subscriptions[type] != null;
  }

  List<NostrFilter> getActiveFilters(SubscriptionType type) {
    final subscription = _subscriptions[type];
    return subscription?.request.filters ?? [];
  }

  void subscribeAll() {
    unsubscribeAll();
    final currentSessions = ref.read(sessionNotifierProvider);
    _updateAllSubscriptions(currentSessions);
  }

  void unsubscribeAll() {
    for (final type in SubscriptionType.values) {
      unsubscribeByType(type);
    }
  }

  void dispose() {
    _sessionListener.close();
    unsubscribeAll();
    _ordersController.close();
    _chatController.close();
  }
}
