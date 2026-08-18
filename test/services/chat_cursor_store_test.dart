import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/services/chat_cursor_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal in-memory double for the two methods the store uses.
class _FakeSharedPreferencesAsync implements SharedPreferencesAsync {
  final Map<String, int> ints = {};

  @override
  Future<int?> getInt(String key) async => ints[key];

  @override
  Future<void> setInt(String key, int value) async {
    ints[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late _FakeSharedPreferencesAsync prefs;
  late ChatCursorStore store;

  const keyPrefix = 'dispute_chat_since_';
  const conversationId = 'dispute-123';
  final now = DateTime.fromMillisecondsSinceEpoch(1755000000 * 1000);

  setUp(() {
    prefs = _FakeSharedPreferencesAsync();
    store = ChatCursorStore(prefs, keyPrefix: keyPrefix);
  });

  group('ChatCursorStore', () {
    test('returns null cursor and since for an unknown conversation',
        () async {
      expect(await store.cursorFor(conversationId), isNull);
      expect(await store.sinceFor(conversationId), isNull);
      expect(store.cachedSinceFor(conversationId), isNull);
    });

    test('advance persists the accepted timestamp under the key prefix',
        () async {
      final accepted = now.subtract(const Duration(minutes: 5));
      await store.advance(conversationId, accepted, now: now);

      expect(await store.cursorFor(conversationId), equals(accepted));
      expect(
        await store.sinceFor(conversationId),
        equals(accepted.subtract(ChatCursorStore.cursorOverlap)),
      );
      expect(prefs.ints.keys, everyElement(startsWith(keyPrefix)));
      expect(prefs.ints, isNotEmpty);
    });

    test('advance clamps a future-dated timestamp to the local clock',
        () async {
      final farFuture = now.add(const Duration(days: 30));
      await store.advance(conversationId, farFuture, now: now);

      expect(await store.cursorFor(conversationId), equals(now));
    });

    test('advance is monotonic and never moves the cursor backward',
        () async {
      final newer = now.subtract(const Duration(minutes: 1));
      final older = now.subtract(const Duration(hours: 2));

      await store.advance(conversationId, newer, now: now);
      await store.advance(conversationId, older, now: now);

      expect(await store.cursorFor(conversationId), equals(newer));
    });

    test('cursor survives a new store instance (persistence)', () async {
      final accepted = now.subtract(const Duration(minutes: 5));
      await store.advance(conversationId, accepted, now: now);

      final freshStore = ChatCursorStore(prefs, keyPrefix: keyPrefix);
      final restored = await freshStore.cursorFor(conversationId);

      // Stored with second precision
      expect(
        restored!.millisecondsSinceEpoch ~/ 1000,
        equals(accepted.millisecondsSinceEpoch ~/ 1000),
      );
    });

    test('cachedSinceFor is available after loading or advancing', () async {
      final accepted = now.subtract(const Duration(minutes: 5));
      await store.advance(conversationId, accepted, now: now);

      expect(
        store.cachedSinceFor(conversationId),
        equals(accepted.subtract(ChatCursorStore.cursorOverlap)),
      );
    });

    test('concurrent out-of-order advances keep the newer timestamp',
        () async {
      final newer = now.subtract(const Duration(minutes: 1));
      final older = now.subtract(const Duration(hours: 2));

      // Both calls start before either completes; serialization must
      // prevent the older timestamp from overwriting the newer one
      await Future.wait([
        store.advance(conversationId, newer, now: now),
        store.advance(conversationId, older, now: now),
      ]);

      expect(await store.cursorFor(conversationId), equals(newer));
      expect(store.cachedSinceFor(conversationId),
          equals(newer.subtract(ChatCursorStore.cursorOverlap)));
    });

    test('warmUp loads persisted cursors into a cold cache', () async {
      final accepted = now.subtract(const Duration(minutes: 5));
      await store.advance(conversationId, accepted, now: now);

      // Fresh instance simulates a cold start: cache empty, prefs populated
      final coldStore = ChatCursorStore(prefs, keyPrefix: keyPrefix);
      expect(coldStore.cachedSinceFor(conversationId), isNull);

      await coldStore.warmUp([conversationId, 'unknown-dispute']);

      final since = coldStore.cachedSinceFor(conversationId);
      expect(since, isNotNull);
      expect(
        since!.millisecondsSinceEpoch ~/ 1000,
        equals(accepted
            .subtract(ChatCursorStore.cursorOverlap)
            .millisecondsSinceEpoch ~/
            1000),
      );
      expect(coldStore.cachedSinceFor('unknown-dispute'), isNull);
    });

    test('conversations track independent cursors', () async {
      final a = now.subtract(const Duration(minutes: 5));
      final b = now.subtract(const Duration(hours: 3));
      await store.advance('dispute-a', a, now: now);
      await store.advance('dispute-b', b, now: now);

      expect(await store.cursorFor('dispute-a'), equals(a));
      expect(await store.cursorFor('dispute-b'), equals(b));
    });

    test('stores with different prefixes do not collide on the same id',
        () async {
      final peerStore = ChatCursorStore(prefs, keyPrefix: 'chat_since_');
      final disputeCursor = now.subtract(const Duration(minutes: 5));
      final peerCursor = now.subtract(const Duration(hours: 3));

      await store.advance('order-1', disputeCursor, now: now);
      await peerStore.advance('order-1', peerCursor, now: now);

      expect(await store.cursorFor('order-1'), equals(disputeCursor));
      expect(await peerStore.cursorFor('order-1'), equals(peerCursor));
      expect(prefs.ints.length, equals(2));
    });

    test('clamp is a pure min against the local clock', () {
      final past = now.subtract(const Duration(seconds: 1));
      final future = now.add(const Duration(seconds: 1));
      expect(ChatCursorStore.clamp(past, now), equals(past));
      expect(ChatCursorStore.clamp(future, now), equals(now));
      expect(ChatCursorStore.clamp(now, now), equals(now));
    });
  });
}
