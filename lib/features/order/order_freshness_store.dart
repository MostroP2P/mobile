import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers, per order, the signed timestamp of the newest message this
/// client has ever acted on.
///
/// `AbstractMostroNotifier` already refuses a message older than the state it
/// would modify, and rebuilds that mark from stored history on sync. That is
/// enough while the history exists — but the history is exactly what a restore
/// deletes. `RestoreService._clearAll` drops sessions, messages and the event
/// dedup store before the node is even contacted, and the trade keys are then
/// re-derived identically from the same master key. For a window afterwards
/// the client has the same identity and no memory, which is the state a
/// replayed `fiat-sent-ok` needs in order to look like news.
///
/// This store is the part that survives. It lives outside the databases the
/// restore clears, holds no trade content — an order id and a timestamp — and
/// only ever moves forward, so a wipe cannot be turned into a way to make old
/// instructions fresh again.
class OrderFreshnessStore {
  /// Cap on remembered orders. Each entry is roughly 60 bytes, so this is well
  /// under a hundred kilobytes; the oldest are dropped first because an order
  /// whose last activity is ancient is not one a replay can usefully target.
  static const int maxEntries = 2000;

  final SharedPreferencesAsync _prefs;

  Map<String, int> _timestamps = {};
  bool _initialized = false;

  /// Tail of the write chain, so concurrent writes land in call order.
  Future<void> _writes = Future<void>.value();

  OrderFreshnessStore(this._prefs);

  bool get isInitialized => _initialized;

  /// Completes when every queued write has finished.
  Future<void> get pendingWrites => _writes;

  Future<void> init() async {
    _timestamps = await _load();
    _initialized = true;
  }

  /// Newest applied timestamp for [orderId], or null if none is remembered.
  int? timestampFor(String orderId) => _timestamps[orderId];

  /// Records [timestamp] for [orderId], keeping the higher of the two.
  ///
  /// Returns true when the stored value moved.
  bool record(String orderId, int timestamp) {
    if (orderId.isEmpty) return false;

    final current = _timestamps[orderId];
    if (current != null && current >= timestamp) return false;

    _timestamps[orderId] = timestamp;
    _prune();
    _persist();
    return true;
  }

  /// Drops everything. For an explicit "forget this device's history" action
  /// only — routine flows must not call it, since clearing reopens precisely
  /// the window this store exists to close.
  Future<void> clear() {
    _timestamps = {};
    return _enqueueWrite(
      () => _prefs.remove(SharedPreferencesKeys.orderFreshness.value),
      'clear order freshness',
    );
  }

  void _prune() {
    if (_timestamps.length <= maxEntries) return;

    final byAge = _timestamps.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    _timestamps = {
      for (final entry in byAge.take(maxEntries)) entry.key: entry.value,
    };
  }

  void _persist() {
    final snapshot = jsonEncode(_timestamps);
    unawaited(
      _enqueueWrite(
        () => _prefs.setString(
          SharedPreferencesKeys.orderFreshness.value,
          snapshot,
        ),
        'persist order freshness',
      ),
    );
  }

  Future<void> _enqueueWrite(
    Future<void> Function() op,
    String description,
  ) {
    final queued = _writes.then((_) => op()).catchError(
          (Object e) => logger.e('Failed to $description: $e'),
        );
    _writes = queued;
    return queued;
  }

  Future<Map<String, int>> _load() async {
    try {
      final json =
          await _prefs.getString(SharedPreferencesKeys.orderFreshness.value);
      if (json == null) return {};

      final decoded = jsonDecode(json);
      if (decoded is! Map) return {};

      final result = <String, int>{};
      decoded.forEach((key, value) {
        // A malformed entry is dropped, never allowed to throw and take the
        // whole store down with it.
        if (key is! String || key.isEmpty) return;
        final timestamp = value is int
            ? value
            : value is String
                ? int.tryParse(value)
                : null;
        if (timestamp != null && timestamp > 0) {
          result[key] = timestamp;
        }
      });
      return result;
    } catch (e) {
      logger.e('Failed to load order freshness: $e');
      return {};
    }
  }
}

final orderFreshnessStoreProvider = Provider<OrderFreshnessStore>((ref) {
  return OrderFreshnessStore(ref.watch(sharedPreferencesProvider));
});
