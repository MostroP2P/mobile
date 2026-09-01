import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/shared/providers/app_init_provider.dart';

/// Startup eagerly created an OrderNotifier (storage watcher + book listener)
/// for EVERY session of the last 30 days, settled or not. Settled orders now
/// initialize lazily — but only those after which Mostro sends nothing that
/// needs a live reaction, and only once the trailing-notice window has
/// passed. `Status.isTerminal` answers a different question (may this session
/// be deleted during cleanup?) and is not reused here.
void main() {
  final now = DateTime(2026, 9, 1, 12);

  MostroMessage withStatus(Status status,
      {Duration age = const Duration(days: 3)}) {
    final message = MostroMessage(
      action: Action.newOrder,
      id: 'o1',
      payload: Order(
        kind: OrderType.sell,
        status: status,
        fiatCode: 'VES',
        fiatAmount: 100,
        paymentMethod: 'cash',
      ),
    );
    message.timestamp = now.subtract(age).millisecondsSinceEpoch;
    return message;
  }

  group('isSettledOrderMessage', () {
    test('settled statuses past the grace window initialize lazily', () {
      for (final status in settledOrderStatuses) {
        expect(isSettledOrderMessage(withStatus(status), now: now), isTrue,
            reason: '$status expects no further traffic');
      }
    });

    test('a settled order still inside the grace window stays eager', () {
      // Trailing notices (bond-slashed, ratings) must still be reacted to
      // live, not only persisted.
      expect(
        isSettledOrderMessage(
            withStatus(Status.canceledByAdmin, age: const Duration(hours: 1)),
            now: now),
        isFalse,
      );
    });

    test('statuses that still expect traffic stay eager', () {
      // settled-hold-invoice: the buyer may still replace a wrong invoice.
      expect(
          isSettledOrderMessage(withStatus(Status.settledHoldInvoice),
              now: now),
          isFalse);
      // canceled: OrderNotifier.sync() re-arms the deferred session deletion
      // through reconcileCanceledBondedSession(), and bond-slashed trails it.
      expect(isSettledOrderMessage(withStatus(Status.canceled), now: now),
          isFalse);
      // success: the rating exchange has no time bound.
      expect(
          isSettledOrderMessage(withStatus(Status.success), now: now), isFalse);
    });

    test('live statuses keep eager initialization', () {
      expect(
          isSettledOrderMessage(withStatus(Status.pending), now: now), isFalse);
      expect(
          isSettledOrderMessage(withStatus(Status.active), now: now), isFalse);
      expect(isSettledOrderMessage(withStatus(Status.fiatSent), now: now),
          isFalse);
    });

    test('anything ambiguous counts as live (conservative)', () {
      expect(isSettledOrderMessage(null, now: now), isFalse);
      expect(
        isSettledOrderMessage(MostroMessage(action: Action.rate, id: 'o1'),
            now: now),
        isFalse,
        reason: 'no order payload',
      );
      final noTimestamp = withStatus(Status.expired);
      noTimestamp.timestamp = null;
      expect(isSettledOrderMessage(noTimestamp, now: now), isFalse,
          reason: 'an unknown age is not proof that nothing is coming');
    });

    test('a seconds timestamp is read in the right unit', () {
      // The daemon sends seconds; the app fills in milliseconds only when the
      // field is absent, so both units coexist in the store.
      final message = withStatus(Status.expired);
      message.timestamp =
          now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
      expect(isSettledOrderMessage(message, now: now), isFalse,
          reason: 'one hour old: still inside the grace window');
    });
  });
}
