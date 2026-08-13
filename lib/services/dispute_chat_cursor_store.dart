import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the per-conversation `since` cursor for dispute chat
/// subscriptions, as the chat spec requires: "subscribe with `since` set to
/// the last processed timestamp, persisted locally, together with a limit".
///
/// The cursor advances only after chatUnwrap accepts an event, clamped to
/// min(accepted_timestamp, local_now) so a future-dated event cannot
/// suppress later messages. Subscriptions subtract [cursorOverlap] so an
/// event late-delivered by a slow relay is not filtered out forever;
/// outer-id dedup absorbs the re-delivered tail.
class DisputeChatCursorStore {
  static const _keyPrefix = 'dispute_chat_since_';

  /// Overlap window subtracted from the cursor when subscribing.
  static const cursorOverlap = Duration(minutes: 10);

  final SharedPreferencesAsync _prefs;
  final Map<String, DateTime> _cache = {};

  /// Per-dispute chain serializing advance() so concurrent calls cannot
  /// interleave their read-compare-write and regress the cursor.
  final Map<String, Future<void>> _advanceQueue = {};

  DisputeChatCursorStore(this._prefs);

  /// Clamp an accepted event timestamp to the local clock.
  static DateTime clamp(DateTime accepted, DateTime now) =>
      accepted.isAfter(now) ? now : accepted;

  /// Last processed timestamp for a conversation, or null if none stored.
  Future<DateTime?> cursorFor(String disputeId) async {
    final cached = _cache[disputeId];
    if (cached != null) return cached;
    final secs = await _prefs.getInt('$_keyPrefix$disputeId');
    if (secs == null) return null;
    final cursor = DateTime.fromMillisecondsSinceEpoch(secs * 1000);
    _cache[disputeId] = cursor;
    return cursor;
  }

  /// Subscription `since` for a conversation: the cursor minus the overlap
  /// window, or null when no cursor is stored yet (callers fall back to the
  /// default lookback).
  Future<DateTime?> sinceFor(String disputeId) async {
    final cursor = await cursorFor(disputeId);
    return cursor?.subtract(cursorOverlap);
  }

  /// Synchronous variant for call sites that build filters synchronously.
  /// Returns null when the cursor is not in memory yet — call [warmUp]
  /// first so persisted cursors are visible after a cold start.
  DateTime? cachedSinceFor(String disputeId) =>
      _cache[disputeId]?.subtract(cursorOverlap);

  /// Load the persisted cursors for the given conversations into the
  /// in-memory cache, so synchronous filter builders see durable state.
  Future<void> warmUp(Iterable<String> disputeIds) async {
    for (final disputeId in disputeIds) {
      await cursorFor(disputeId);
    }
  }

  /// Advance the cursor after an accepted event. Monotonic (never moves
  /// backward), clamped to the local clock, and serialized per dispute.
  Future<void> advance(
    String disputeId,
    DateTime accepted, {
    DateTime? now,
  }) {
    final previous = _advanceQueue[disputeId] ?? Future.value();
    final next = previous
        .catchError((_) {})
        .then((_) => _advanceSerialized(disputeId, accepted, now: now));
    _advanceQueue[disputeId] = next;
    return next;
  }

  Future<void> _advanceSerialized(
    String disputeId,
    DateTime accepted, {
    DateTime? now,
  }) async {
    final clamped = clamp(accepted, now ?? DateTime.now());
    final current = await cursorFor(disputeId);
    if (current != null && !clamped.isAfter(current)) return;
    _cache[disputeId] = clamped;
    await _prefs.setInt(
      '$_keyPrefix$disputeId',
      clamped.millisecondsSinceEpoch ~/ 1000,
    );
  }
}

final disputeChatCursorStoreProvider = Provider<DisputeChatCursorStore>(
  (ref) => DisputeChatCursorStore(ref.watch(sharedPreferencesProvider)),
);
