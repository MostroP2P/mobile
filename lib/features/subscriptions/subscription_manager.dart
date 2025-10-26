import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/core/models/relay_list_event.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
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
  final _relayListController = StreamController<RelayListEvent>.broadcast();
  final _adminController = StreamController<NostrEvent>.broadcast();

  Stream<NostrEvent> get orders => _ordersController.stream;
  Stream<NostrEvent> get chat => _chatController.stream;
  Stream<RelayListEvent> get relayList => _relayListController.stream;
  Stream<NostrEvent> get admin => _adminController.stream;

  SubscriptionManager(this.ref) {
    _initSessionListener();
    // Ensure resources are released with provider/container lifecycle
    ref.onDispose(dispose);
    _initializeExistingSessions();
  }

  void _initSessionListener() {
    _sessionListener = ref.listen<List<Session>>(
      sessionNotifierProvider,
      (previous, current) {
        _updateAllSubscriptions(current);
      },
      fireImmediately: false,
      onError: (error, stackTrace) {
        _logger.e('Error in session listener',
            error: error, stackTrace: stackTrace);
      },
    );
  }

  /// CRITICAL: Initialize subscriptions for existing sessions
  /// DO NOT REMOVE: Fixes stuck orders bug when app restarts with existing sessions
  ///
  /// This method ensures that subscriptions are created for sessions that already
  /// exist when SubscriptionManager is created, since fireImmediately: false
  /// prevents automatic initialization.
  void _initializeExistingSessions() {
    try {
      // Always initialize admin subscription (independent of sessions)
      _initializeAdminSubscription();

      final existingSessions = ref.read(sessionNotifierProvider);
      if (existingSessions.isNotEmpty) {
        _logger.i('Initializing subscriptions for ${existingSessions.length} existing sessions');
        _updateAllSubscriptions(existingSessions);
      } else {
        _logger.i('No existing sessions found during SubscriptionManager initialization');
      }
    } catch (e, stackTrace) {
      _logger.e('Error initializing existing sessions',
          error: e, stackTrace: stackTrace);
    }
  }

  /// Initialize admin subscription independently of sessions
  void _initializeAdminSubscription() {
    try {
      final masterKey = ref.read(keyManagerProvider).masterKeyPair;
      if (masterKey == null) {
        _logger.i('No master key available, skipping admin subscription');
        return;
      }

      final filter = NostrFilter(
        kinds: [1059],
        p: [masterKey.public],
      );

      subscribe(
        type: SubscriptionType.admin,
        filter: filter,
      );

      _logger.i('Admin subscription initialized for master key');
    } catch (e, stackTrace) {
      _logger.e('Failed to initialize admin subscription',
          error: e, stackTrace: stackTrace);
    }
  }


  void _updateAllSubscriptions(List<Session> sessions) {
    if (sessions.isEmpty) {
      _logger.i('No sessions available, clearing session-based subscriptions');
      _clearAllSubscriptions();
      return;
    }

    for (final type in SubscriptionType.values) {
      // Admin subscription is managed independently
      if (type == SubscriptionType.admin) continue;
      _updateSubscription(type, sessions);
    }
  }

  void _clearAllSubscriptions() {
    for (final type in SubscriptionType.values) {
      // Keep admin subscription active (independent of sessions)
      if (type == SubscriptionType.admin) continue;
      unsubscribeByType(type);
    }
  }

  void _updateSubscription(SubscriptionType type, List<Session> sessions) {
    if (sessions.isEmpty) {
      _logger.i('No sessions for $type subscription');
      unsubscribeByType(type);
      return;
    }

    try {
      final filter = _createFilterForType(type, sessions);
      if (filter == null) {
        return;
      }
      // Replace existing subscription only when we have a new filter to apply
      unsubscribeByType(type);
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
      case SubscriptionType.admin:
        // Admin subscription uses master key for administrative messages
        final masterKey = ref.read(keyManagerProvider).masterKeyPair;
        if (masterKey == null) {
          return null;
        }
        return NostrFilter(
          kinds: [1059],
          p: [masterKey.public],
        );
      case SubscriptionType.relayList:
        // Relay list subscriptions are handled separately via subscribeToMostroRelayList
        return null;
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
        case SubscriptionType.admin:
          _adminController.add(event);
          break;
        case SubscriptionType.relayList:
          final relayListEvent = RelayListEvent.fromEvent(event);
          if (relayListEvent != null) {
            _relayListController.add(relayListEvent);
          }
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
      case SubscriptionType.admin:
        return admin;
      case SubscriptionType.relayList:
        // RelayList subscriptions should use subscribeToMostroRelayList() instead
        throw UnsupportedError('Use subscribeToMostroRelayList() for relay list subscriptions');
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
      // Keep admin subscription active (independent of sessions)
      if (type == SubscriptionType.admin) continue;
      unsubscribeByType(type);
    }
  }

  /// Subscribes to kind 10002 relay list events from a specific Mostro instance.
  /// This is used to automatically sync relays with the configured Mostro instance.
  void subscribeToMostroRelayList(String mostroPubkey) {
    try {
      final filter = NostrFilter(
        kinds: [10002],
        authors: [mostroPubkey],
        limit: 1, // Only get the most recent relay list
      );

      _subscribeToRelayList(filter);

      _logger.i('Subscribed to relay list for Mostro: $mostroPubkey');
    } catch (e, stackTrace) {
      _logger.e('Failed to subscribe to Mostro relay list',
          error: e, stackTrace: stackTrace);
    }
  }

  /// Internal method to handle relay list subscriptions
  void _subscribeToRelayList(NostrFilter filter) {
    final nostrService = ref.read(nostrServiceProvider);

    final request = NostrRequest(
      filters: [filter],
    );

    final stream = nostrService.subscribeToEvents(request);
    final streamSubscription = stream.listen(
      (event) {
        // Handle relay list events directly
        final relayListEvent = RelayListEvent.fromEvent(event);
        if (relayListEvent != null) {
          _relayListController.add(relayListEvent);
        }
      },
      onError: (error, stackTrace) {
        _logger.e('Error in relay list subscription',
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

    // Cancel existing relay list subscription if any
    if (_subscriptions.containsKey(SubscriptionType.relayList)) {
      _subscriptions[SubscriptionType.relayList]!.cancel();
    }

    _subscriptions[SubscriptionType.relayList] = subscription;
  }

  /// Unsubscribes from Mostro relay list events
  void unsubscribeFromMostroRelayList() {
    unsubscribeByType(SubscriptionType.relayList);
    _logger.i('Unsubscribed from Mostro relay list');
  }

  void dispose() {
    _sessionListener.close();
    unsubscribeAll();
    _ordersController.close();
    _chatController.close();
    _relayListController.close();
    _adminController.close();
  }
}
