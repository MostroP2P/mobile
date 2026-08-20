import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/features/order/order_freshness_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSharedPreferencesAsync implements SharedPreferencesAsync {
  final Map<String, String> strings = {};
  final bool failWrites;

  _FakeSharedPreferencesAsync({this.failWrites = false});

  @override
  Future<String?> getString(String key) async => strings[key];

  @override
  Future<void> setString(String key, String value) async {
    if (failWrites) throw Exception('disk full');
    strings[key] = value;
  }

  @override
  Future<void> remove(String key) async => strings.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

final _key = SharedPreferencesKeys.orderFreshness.value;
const _orderA = 'a3f1c2d4-1111-2222-3333-444455556666';
const _orderB = 'b4e2d3c5-7777-8888-9999-aaaabbbbcccc';

void main() {
  late _FakeSharedPreferencesAsync prefs;
  late OrderFreshnessStore store;

  final now = DateTime(2026, 3, 1).millisecondsSinceEpoch;
  final earlier = DateTime(2026, 2, 1).millisecondsSinceEpoch;

  setUp(() async {
    prefs = _FakeSharedPreferencesAsync();
    store = OrderFreshnessStore(prefs);
    await store.init();
  });

  group('basics', () {
    test('knows nothing about an unseen order', () {
      expect(store.timestampFor(_orderA), isNull);
    });

    test('records and reports a timestamp', () {
      expect(store.record(_orderA, now), isTrue);
      expect(store.timestampFor(_orderA), now);
    });

    test('orders are tracked independently', () {
      store.record(_orderA, now);
      store.record(_orderB, earlier);

      expect(store.timestampFor(_orderA), now);
      expect(store.timestampFor(_orderB), earlier);
    });
  });

  // Only ever forward. A store that could be walked back would hand an
  // attacker the very thing it exists to deny.
  group('monotonicity', () {
    test('moves forward', () {
      store.record(_orderA, earlier);
      expect(store.record(_orderA, now), isTrue);
      expect(store.timestampFor(_orderA), now);
    });

    test('refuses to move backward', () {
      store.record(_orderA, now);
      expect(store.record(_orderA, earlier), isFalse);
      expect(store.timestampFor(_orderA), now);
    });

    test('an equal timestamp is a no-op', () {
      store.record(_orderA, now);
      expect(store.record(_orderA, now), isFalse);
    });
  });

  // The point of the whole store: a restore clears the message history, the
  // trade keys are re-derived identically, and this is the only thing left
  // that knows the order had already moved past that message.
  group('surviving a wipe', () {
    test('a reopened store still refuses a replayed message', () async {
      store.record(_orderA, now);
      await store.pendingWrites;

      final afterWipe = OrderFreshnessStore(prefs);
      await afterWipe.init();

      expect(afterWipe.timestampFor(_orderA), now);
      expect(afterWipe.record(_orderA, earlier), isFalse);
    });

    test('an empty store knows nothing', () async {
      final fresh = OrderFreshnessStore(_FakeSharedPreferencesAsync());
      await fresh.init();

      expect(fresh.timestampFor(_orderA), isNull);
    });
  });

  group('durability', () {
    test('memory stays authoritative when writes fail', () async {
      final failing = OrderFreshnessStore(
        _FakeSharedPreferencesAsync(failWrites: true),
      );
      await failing.init();

      expect(failing.record(_orderA, now), isTrue);
      expect(failing.timestampFor(_orderA), now);
      await failing.pendingWrites;
      expect(failing.timestampFor(_orderA), now);
    });

    test('writes the whole snapshot', () async {
      store.record(_orderA, now);
      store.record(_orderB, earlier);
      await store.pendingWrites;

      expect(jsonDecode(prefs.strings[_key]!), {
        _orderA: now,
        _orderB: earlier,
      });
    });

    test('clear empties both memory and disk', () async {
      store.record(_orderA, now);
      await store.clear();

      expect(store.timestampFor(_orderA), isNull);
      expect(prefs.strings[_key], isNull);
    });
  });

  group('corrupt storage', () {
    Future<OrderFreshnessStore> storeWith(String raw) async {
      final p = _FakeSharedPreferencesAsync()..strings[_key] = raw;
      final s = OrderFreshnessStore(p);
      await s.init();
      return s;
    }

    test('unparseable json yields an empty store', () async {
      final s = await storeWith('not json');
      expect(s.timestampFor(_orderA), isNull);
      expect(s.isInitialized, isTrue);
    });

    test('malformed entries are dropped, good ones kept', () async {
      final s = await storeWith(jsonEncode({
        _orderA: now,
        _orderB: 'garbage',
        'zero': 0,
        'negative': -5,
      }));

      expect(s.timestampFor(_orderA), now);
      expect(s.timestampFor(_orderB), isNull);
      expect(s.timestampFor('zero'), isNull);
      expect(s.timestampFor('negative'), isNull);
    });
  });

  group('pruning', () {
    test('keeps the newest entries when over the cap', () {
      for (var i = 0; i < OrderFreshnessStore.maxEntries + 50; i++) {
        store.record('order-$i', now + i);
      }

      // The oldest were dropped; the newest survive.
      expect(store.timestampFor('order-0'), isNull);
      expect(
        store.timestampFor('order-${OrderFreshnessStore.maxEntries + 49}'),
        isNotNull,
      );
    });
  });
}
