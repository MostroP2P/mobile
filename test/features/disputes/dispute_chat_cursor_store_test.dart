import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/services/dispute_chat_cursor_store.dart';
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
  late DisputeChatCursorStore store;

  const disputeId = 'dispute-123';
  final now = DateTime.fromMillisecondsSinceEpoch(1755000000 * 1000);

  setUp(() {
    prefs = _FakeSharedPreferencesAsync();
    store = DisputeChatCursorStore(prefs);
  });

  group('DisputeChatCursorStore', () {
    test('returns null cursor and since for an unknown conversation',
        () async {
      expect(await store.cursorFor(disputeId), isNull);
      expect(await store.sinceFor(disputeId), isNull);
      expect(store.cachedSinceFor(disputeId), isNull);
    });

    test('advance persists the accepted timestamp', () async {
      final accepted = now.subtract(const Duration(minutes: 5));
      await store.advance(disputeId, accepted, now: now);

      expect(await store.cursorFor(disputeId), equals(accepted));
      expect(
        await store.sinceFor(disputeId),
        equals(accepted.subtract(DisputeChatCursorStore.cursorOverlap)),
      );
      expect(prefs.ints, isNotEmpty);
    });

    test('advance clamps a future-dated timestamp to the local clock',
        () async {
      final farFuture = now.add(const Duration(days: 30));
      await store.advance(disputeId, farFuture, now: now);

      expect(await store.cursorFor(disputeId), equals(now));
    });

    test('advance is monotonic and never moves the cursor backward',
        () async {
      final newer = now.subtract(const Duration(minutes: 1));
      final older = now.subtract(const Duration(hours: 2));

      await store.advance(disputeId, newer, now: now);
      await store.advance(disputeId, older, now: now);

      expect(await store.cursorFor(disputeId), equals(newer));
    });

    test('cursor survives a new store instance (persistence)', () async {
      final accepted = now.subtract(const Duration(minutes: 5));
      await store.advance(disputeId, accepted, now: now);

      final freshStore = DisputeChatCursorStore(prefs);
      final restored = await freshStore.cursorFor(disputeId);

      // Stored with second precision
      expect(
        restored!.millisecondsSinceEpoch ~/ 1000,
        equals(accepted.millisecondsSinceEpoch ~/ 1000),
      );
    });

    test('cachedSinceFor is available after loading or advancing', () async {
      final accepted = now.subtract(const Duration(minutes: 5));
      await store.advance(disputeId, accepted, now: now);

      expect(
        store.cachedSinceFor(disputeId),
        equals(accepted.subtract(DisputeChatCursorStore.cursorOverlap)),
      );
    });

    test('conversations track independent cursors', () async {
      final a = now.subtract(const Duration(minutes: 5));
      final b = now.subtract(const Duration(hours: 3));
      await store.advance('dispute-a', a, now: now);
      await store.advance('dispute-b', b, now: now);

      expect(await store.cursorFor('dispute-a'), equals(a));
      expect(await store.cursorFor('dispute-b'), equals(b));
    });

    test('clamp is a pure min against the local clock', () {
      final past = now.subtract(const Duration(seconds: 1));
      final future = now.add(const Duration(seconds: 1));
      expect(DisputeChatCursorStore.clamp(past, now), equals(past));
      expect(DisputeChatCursorStore.clamp(future, now), equals(now));
      expect(DisputeChatCursorStore.clamp(now, now), equals(now));
    });
  });
}
