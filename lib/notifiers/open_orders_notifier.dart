import 'dart:async';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/repositories/order_repository_interface.dart';
import 'package:mostro_mobile/services/nostr_service.dart';

class OpenOrdersNotifier extends StateNotifier<List<NostrEvent>>
    implements OrderRepository {
  final NostrService _nostrService;
  final Map<String, NostrEvent> _events = {};

  OpenOrdersNotifier(this._nostrService) : super([]);

  StreamSubscription<NostrEvent>? _subscription;

  /// Subscribes to events matching the given filter.
  ///
  /// @param filter The filter criteria for events.
  /// @throws ArgumentError if filter is null
  void subscribeToOrders(NostrFilter filter) {
    ArgumentError.checkNotNull(filter, 'filter');

    // Cancel existing subscription if any
    _subscription?.cancel();

    _subscription = _nostrService.subscribeToEvents(filter).listen((event) {
      final key = '${event.kind}-${event.pubkey}-${event.orderId}';
      _events[key] = event;
      // Update state with a list of current events
      state = _events.values.toList();
    }, onError: (error) {
      // Log error
      print('Error in order subscription: $error');
    });
  }

  /// Cleans up expired orders from the `_events` map.
  void cleanupExpiredOrders(Duration expirationDuration) {
    final now = DateTime.now();
    final expiredKeys = _events.entries
        .where((entry) =>
            entry.value.createdAt != null &&
            now
                    .difference(entry.value.createdAt!)
                    .compareTo(expirationDuration) >
                0)
        .map((entry) => entry.key)
        .toList();

    // Remove expired events
    for (final key in expiredKeys) {
      _events.remove(key);
    }

    // Update state after cleanup
    state = _events.values.toList();
  }

  void updateOrders(List<NostrEvent> newOrders) {
    debugPrint('Updating orders: $newOrders');
    state = newOrders;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _events.clear();
    super.dispose();
  }
}
