import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/features/order/notifiers/abstract_mostro_notifier.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';

/// Exposes the guard under test. Nothing is overridden — the rule exercised
/// here is the production one.
class _Probe extends AbstractMostroNotifier {
  _Probe(super.orderId, super.ref);

  bool check(MostroMessage msg) => supersedesAppliedState(msg);

  void setApplied(int? timestamp) => lastAppliedTimestamp = timestamp;
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

  setUp(() {
    probeProvider = Provider<_Probe>((ref) => _Probe('order-1', ref));
    container = ProviderContainer(
      overrides: [
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
}
