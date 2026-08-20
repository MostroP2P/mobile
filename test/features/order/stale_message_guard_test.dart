import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/features/order/order_freshness_store.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:mostro_mobile/features/order/notifiers/abstract_mostro_notifier.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';

/// Exposes the guard under test. Nothing is overridden — the rule exercised
/// here is the production one.
class _Probe extends AbstractMostroNotifier {
  _Probe(super.orderId, super.ref);

  bool check(MostroMessage msg) => supersedesAppliedState(msg);

  void setApplied(int? timestamp) => lastAppliedTimestamp = timestamp;

  void anchor(int? timestamp) => anchorAppliedTimestamp(timestamp);
}

class _FakePrefs implements SharedPreferencesAsync {
  final Map<String, String> strings = {};

  @override
  Future<String?> getString(String key) async => strings[key];

  @override
  Future<void> setString(String key, String value) async {
    strings[key] = value;
  }

  @override
  Future<void> remove(String key) async => strings.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _StubSessionNotifier extends StateNotifier<List<Session>>
    implements SessionNotifier {
  _StubSessionNotifier() : super(const []);

  @override
  Session? getSessionByOrderId(String orderId) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  final at = DateTime(2026, 3, 1);
  final now = at.millisecondsSinceEpoch;
  final hourAgo = at.subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
  final weekAgo = at.subtract(const Duration(days: 7)).millisecondsSinceEpoch;

  late ProviderContainer container;
  late Provider<_Probe> probeProvider;
  late _FakePrefs prefs;

  setUp(() {
    prefs = _FakePrefs();
    probeProvider = Provider<_Probe>((ref) => _Probe('order-1', ref));
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        sessionNotifierProvider.overrideWith((ref) => _StubSessionNotifier()),
      ],
    );
  });

  tearDown(() => container.dispose());

  _Probe probe() => container.read(probeProvider);

  MostroMessage message(int? timestamp) => MostroMessage(
        action: Action.fiatSentOk,
        id: 'order-1',
        timestamp: timestamp,
      );

  // MM-021's payload: a replayed message is authentic and passes every
  // signature check, because it *is* the node's message. What marks it as an
  // attack is that it describes a past this order has already moved beyond.
  group('supersedesAppliedState', () {
    test('a newer message is applied', () {
      final p = probe()..setApplied(hourAgo);
      expect(p.check(message(now)), isTrue);
    });

    test('a message from a week ago cannot modify newer state', () {
      final p = probe()..setApplied(now);
      expect(p.check(message(weekAgo)), isFalse);
    });

    test('an equally dated message is applied', () {
      // A node can emit several messages within one second; exact
      // re-deliveries are stopped earlier by event-id dedup.
      final p = probe()..setApplied(now);
      expect(p.check(message(now)), isTrue);
    });

    test('the first message is always applied', () {
      expect(probe().check(message(now)), isTrue);
    });

    // v1 gift wrap has no usable clock — NIP-59 randomises those timestamps
    // by design — so refusing untimestamped messages would break v1 outright.
    test('an untimestamped message fails open', () {
      final p = probe()..setApplied(now);
      expect(p.check(message(null)), isTrue);
    });
  });

  // The concrete scenario: a seller who has already settled sees a replayed
  // fiat-sent-ok. Without the guard it re-arms Release.
  group('replayed fiat-sent-ok on a settled order', () {
    test('would move the state backwards if applied', () {
      final settled = OrderState(
        status: Status.settledHoldInvoice,
        action: Action.released,
        order: null,
      );

      // Proof the message is not inert: applied, it does change the state.
      final ifApplied = settled.updateWith(message(weekAgo));
      expect(ifApplied.action, Action.fiatSentOk);
      expect(ifApplied.status, isNot(settled.status));
    });

    test('is refused once newer state exists', () {
      final p = probe()..setApplied(now);
      expect(p.check(message(weekAgo)), isFalse);
    });
  });

  // MM-021's last mile. A restore deletes the message history and re-derives
  // the same trade keys, leaving the notifier with no in-memory mark. The
  // durable store is what keeps the order from accepting an archived message
  // as news during that window.
  group('freshness that survives a wiped history', () {
    Future<void> seedStore(int timestamp) async {
      prefs.strings[SharedPreferencesKeys.orderFreshness.value] =
          jsonEncode({'order-1': timestamp});
      await container.read(orderFreshnessStoreProvider).init();
    }

    test('a fresh notifier inherits the remembered mark', () async {
      await seedStore(now);

      // No message has been folded in this process — the mark comes entirely
      // from storage, exactly as it would right after a restore.
      expect(probe().check(message(weekAgo)), isFalse);
    });

    test('and still accepts genuinely newer messages', () async {
      await seedStore(weekAgo);

      expect(probe().check(message(now)), isTrue);
    });

    test('applying a message records it durably', () async {
      await container.read(orderFreshnessStoreProvider).init();
      final p = probe()..setApplied(now);
      await container.read(orderFreshnessStoreProvider).pendingWrites;

      expect(
        container.read(orderFreshnessStoreProvider).timestampFor('order-1'),
        now,
      );
      expect(p.check(message(weekAgo)), isFalse);
    });

    test('the in-memory mark cannot lower the remembered one', () async {
      await seedStore(now);

      final p = probe()..setApplied(weekAgo);

      // The store only moves forward, and the guard takes the higher of the
      // two, so a stale local value cannot reopen the window.
      expect(p.check(message(weekAgo)), isFalse);
    });
  });
  // A restore wipes the message history and then applies the node's snapshot.
  // The snapshot's own message is dated with the order's creation time, which
  // predates its entire lifecycle — so without a separate anchor the mark
  // either stays null or lands far enough back that every archived message
  // still reads as news.
  group('freshness anchored to a restored snapshot', () {
    setUp(() async {
      await container.read(orderFreshnessStoreProvider).init();
    });

    test('the snapshot time is what the mark records, not the message date',
        () {
      final p = probe()..anchor(now);

      // hourAgo is newer than the order's creation time but older than the
      // snapshot: exactly the archived lifecycle event this closes off.
      expect(p.check(message(hourAgo)), isFalse);
      expect(p.check(message(weekAgo)), isFalse);
    });

    test('messages the snapshot could not have folded in are still applied',
        () {
      final p = probe()..anchor(hourAgo);

      expect(p.check(message(now)), isTrue);
    });

    test('a null snapshot time leaves the mark untouched', () {
      // v1 gift wrap has no signed clock, so restore yields null rather than
      // a guess. Nothing is anchored and the guard keeps failing open.
      final p = probe()..anchor(null);

      expect(p.check(message(weekAgo)), isTrue);
    });

    test('anchoring never moves the mark backwards', () {
      final p = probe()
        ..setApplied(now)
        ..anchor(weekAgo);

      expect(p.check(message(hourAgo)), isFalse);
    });

    test('the anchor survives into the durable store', () async {
      probe().anchor(now);
      await container.read(orderFreshnessStoreProvider).pendingWrites;

      expect(
        container.read(orderFreshnessStoreProvider).timestampFor('order-1'),
        now,
      );
    });
  });

}
