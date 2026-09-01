import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the per-conversation `since` cursor for chat subscriptions, as
/// the chat spec requires: "subscribe with `since` set to the last processed
/// timestamp, persisted locally, together with a limit".
///
/// The cursor advances only after chatUnwrap accepts an event, clamped to
/// min(accepted_timestamp, local_now) so a future-dated event cannot
/// suppress later messages. Subscriptions subtract [cursorOverlap] so an
/// event late-delivered by a slow relay is not filtered out forever;
/// outer-id dedup absorbs the re-delivered tail.
///
/// One instance per conversation namespace: [keyPrefix] scopes the
/// SharedPreferences keys (dispute chat by disputeId, peer chat by orderId).
class ChatCursorStore {
  /// Overlap window subtracted from the cursor when subscribing.
  static const cursorOverlap = Duration(minutes: 10);

  /// Dispute chat namespace, keyed by disputeId. The prefix predates the
  /// generalization; keeping it preserves cursors stored by older builds.
  static const disputeKeyPrefix = 'dispute_chat_since_';

  /// Orders (node message) namespace, keyed by the node pubkey: one live
  /// orders subscription exists per connected node.
  static const ordersKeyPrefix = 'orders_since_';

  /// Peer (buyer-seller) chat namespace, keyed by orderId. Shared with the
  /// background isolate, which builds its own store without Riverpod.
  static const peerKeyPrefix = 'chat_since_';

  final String _keyPrefix;
  final SharedPreferencesAsync _prefs;
  final Map<String, DateTime> _cache = {};

  /// Per-conversation chain serializing advance() so concurrent calls cannot
  /// interleave their read-compare-write and regress the cursor.
  final Map<String, Future<void>> _advanceQueue = {};

  ChatCursorStore(this._prefs, {required String keyPrefix})
      : _keyPrefix = keyPrefix;

  /// Clamp an accepted event timestamp to the local clock.
  static DateTime clamp(DateTime accepted, DateTime now) =>
      accepted.isAfter(now) ? now : accepted;

  /// Last processed timestamp for a conversation, or null if none stored.
  Future<DateTime?> cursorFor(String conversationId) async {
    final cached = _cache[conversationId];
    if (cached != null) return cached;
    final secs = await _prefs.getInt('$_keyPrefix$conversationId');
    if (secs == null) return null;
    final cursor = DateTime.fromMillisecondsSinceEpoch(secs * 1000);
    _cache[conversationId] = cursor;
    return cursor;
  }

  /// Subscription `since` for a conversation: the cursor minus the overlap
  /// window, or null when no cursor is stored yet (callers fall back to the
  /// default lookback).
  Future<DateTime?> sinceFor(String conversationId) async {
    final cursor = await cursorFor(conversationId);
    return cursor?.subtract(cursorOverlap);
  }

  /// Synchronous variant for call sites that build filters synchronously.
  /// Returns null when the cursor is not in memory yet — call [warmUp]
  /// first so persisted cursors are visible after a cold start.
  DateTime? cachedSinceFor(String conversationId) =>
      _cache[conversationId]?.subtract(cursorOverlap);

  /// Load the persisted cursors for the given conversations into the
  /// in-memory cache, so synchronous filter builders see durable state.
  Future<void> warmUp(Iterable<String> conversationIds) async {
    for (final conversationId in conversationIds) {
      await cursorFor(conversationId);
    }
  }

  /// Advance the cursor after an accepted event. Monotonic (never moves
  /// backward), clamped to the local clock, and serialized per conversation.
  Future<void> advance(
    String conversationId,
    DateTime accepted, {
    DateTime? now,
  }) {
    final previous = _advanceQueue[conversationId] ?? Future.value();
    final next = previous
        .catchError((_) {})
        .then((_) => _advanceSerialized(conversationId, accepted, now: now));
    _advanceQueue[conversationId] = next;
    return next;
  }

  Future<void> _advanceSerialized(
    String conversationId,
    DateTime accepted, {
    DateTime? now,
  }) async {
    final clamped = clamp(accepted, now ?? DateTime.now());
    final current = await cursorFor(conversationId);
    if (current != null && !clamped.isAfter(current)) return;
    _cache[conversationId] = clamped;
    await _prefs.setInt(
      '$_keyPrefix$conversationId',
      clamped.millisecondsSinceEpoch ~/ 1000,
    );
  }
}

/// Dispute chat cursors, keyed by disputeId.
final disputeChatCursorStoreProvider = Provider<ChatCursorStore>(
  (ref) => ChatCursorStore(
    ref.watch(sharedPreferencesProvider),
    keyPrefix: ChatCursorStore.disputeKeyPrefix,
  ),
);

/// Peer (buyer-seller) chat cursors, keyed by orderId.
final chatCursorStoreProvider = Provider<ChatCursorStore>(
  (ref) => ChatCursorStore(
    ref.watch(sharedPreferencesProvider),
    keyPrefix: ChatCursorStore.peerKeyPrefix,
  ),
);

/// Orders (node kind-14 message) cursors, keyed by the node pubkey.
final ordersCursorStoreProvider = Provider<ChatCursorStore>(
  (ref) => ChatCursorStore(
    ref.watch(sharedPreferencesProvider),
    keyPrefix: ChatCursorStore.ordersKeyPrefix,
  ),
);
