import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/features/order/settlement_terms_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A store backed by whatever the platform channel mock holds, so a second
/// instance reads what the first one wrote — which is the whole point of the
/// anchors surviving a process that ended mid-commitment.
SettlementTermsStore _store() => SettlementTermsStore(SharedPreferencesAsync());

final _tradeKey = 'a' * 64;
final _otherKey = 'b' * 64;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('SettlementTermsStore', () {
    test('hands back what a trade committed to', () async {
      final store = _store();
      await store.init();

      await store.pin(
        _tradeKey,
        amountSats: 100000,
        feeRate: 0.006,
        fiatCode: 'USD',
        fiatAmount: 100,
        premium: 2.5,
      );

      final terms = store.termsFor(_tradeKey)!;
      expect(terms.amountSats, 100000);
      expect(terms.feeRate, 0.006);
      expect(terms.fiatCode, 'USD');
      expect(terms.fiatAmount, 100);
      expect(terms.premium, 2.5);
    });

    test('knows nothing about a trade that never pinned', () async {
      final store = _store();
      await store.init();

      expect(store.termsFor(_otherKey), isNull);
    });

    test('survives a process that ended before the daemon replied', () async {
      // The finding's first scenario. The commitment is published right after
      // pin() returns; if the app dies there, the trade stands remotely and
      // these are the only anchors left.
      final before = _store();
      await before.init();
      await before.pin(_tradeKey, amountSats: 100000, feeRate: 0.006);
      await before.pendingWrites;

      final after = _store();
      await after.init();

      expect(after.termsFor(_tradeKey)!.amountSats, 100000);
      expect(after.termsFor(_tradeKey)!.feeRate, 0.006);
    });

    test('outlives a node switch and the session wipe it performs', () async {
      // Node A -> B -> A. The restore clears the session store outright and
      // rebuilds every session from the node's data, so this store is what
      // keeps a committed trade from coming back as a legacy one.
      final onNodeA = _store();
      await onNodeA.init();
      await onNodeA.pin(_tradeKey, amountSats: 100000, feeRate: 0.006);
      await onNodeA.pendingWrites;

      // Switching to B and back rebuilds the store from disk twice; nothing
      // in that path is allowed to clear it.
      final onNodeB = _store();
      await onNodeB.init();
      expect(onNodeB.termsFor(_tradeKey), isNotNull);

      final backOnA = _store();
      await backOnA.init();
      expect(backOnA.termsFor(_tradeKey)!.amountSats, 100000);
    });

    test('keeps the terms the first commitment pinned', () async {
      // A retake must not move the anchor: the trade was agreed once.
      final store = _store();
      await store.init();

      await store.pin(_tradeKey, amountSats: 100000, feeRate: 0.006);
      await store.pin(_tradeKey, amountSats: 999999, feeRate: 0.9);

      expect(store.termsFor(_tradeKey)!.amountSats, 100000);
      expect(store.termsFor(_tradeKey)!.feeRate, 0.006);
    });

    test('records that pinning ran even where there was nothing to pin',
        () async {
      // A market-price take before the info event arrives pins neither
      // figure. The record still has to exist, or the trade is
      // indistinguishable from one that predates pinning and goes back to
      // reading whatever the node publishes next.
      final store = _store();
      await store.init();

      await store.pin(_tradeKey);

      final terms = store.termsFor(_tradeKey);
      expect(terms, isNotNull);
      expect(terms!.amountSats, isNull);
      expect(terms.feeRate, isNull);
    });

    test('drops an anchor for a session the user deleted', () async {
      final store = _store();
      await store.init();
      await store.pin(_tradeKey, amountSats: 100000);

      await store.forget(_tradeKey);
      await store.pendingWrites;

      final reopened = _store();
      await reopened.init();
      expect(reopened.termsFor(_tradeKey), isNull);
    });

    test('prunes an anchor older than the retention window', () async {
      final store = _store();
      await store.init();
      await store.pin(
        _tradeKey,
        amountSats: 100000,
        pinnedAt: DateTime.now()
            .subtract(SettlementTermsStore.retention * 2),
      );
      await store.pin(_otherKey, amountSats: 50000);
      await store.pendingWrites;

      final reopened = _store();
      await reopened.init();

      expect(reopened.termsFor(_tradeKey), isNull);
      expect(reopened.termsFor(_otherKey), isNotNull);
    });

    test('will not write over anchors it never managed to read', () async {
      // The read failing says nothing about the contents: the persisted map
      // may be perfectly good. Serializing memory over it would erase the
      // anchors of every other trade in flight, and those trades would go
      // back to whatever the node currently advertises.
      final seeded = _store();
      await seeded.init();
      await seeded.pin(_otherKey, amountSats: 50000);
      await seeded.pendingWrites;

      final unreadable = _ThrowingReadPrefs();
      final blind = SettlementTermsStore(unreadable);
      await blind.init();
      await blind.pin(_tradeKey, amountSats: 100000);
      await blind.pendingWrites;

      expect(unreadable.writes, isEmpty);
    });

    test('treats an unreadable record as no record at all', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData(<String, Object>{
        'settlement_pinned_terms': 'not json',
      });

      final store = _store();
      await store.init();

      expect(store.termsFor(_tradeKey), isNull);
    });

    test('overwrites a stored value it could read but not parse', () async {
      // The opposite of the case above: there is nothing behind a corrupt
      // value to preserve, so refusing to write would leave pinning broken
      // for good.
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData(<String, Object>{
        'settlement_pinned_terms': 'not json',
      });

      final store = _store();
      await store.init();
      await store.pin(_tradeKey, amountSats: 100000);
      await store.pendingWrites;

      final reopened = _store();
      await reopened.init();
      expect(reopened.termsFor(_tradeKey)!.amountSats, 100000);
    });
  });
}

/// Reads throw; writes are recorded so a test can assert none happened.
class _ThrowingReadPrefs implements SharedPreferencesAsync {
  final List<String> writes = [];

  @override
  Future<String?> getString(String key, {Object? options}) async {
    throw StateError('platform unavailable');
  }

  @override
  Future<void> setString(String key, String value, {Object? options}) async {
    writes.add(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
