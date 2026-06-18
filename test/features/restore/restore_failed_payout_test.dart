import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/features/restore/restore_manager.dart';

/// Regression coverage for issue #615: restoring an order that Mostro reports
/// as `settled-hold-invoice` after a failed Lightning payout must land on the
/// new-invoice prompt (`add-invoice` + `payment-failed`), not "paying sats"
/// (`released` + `settled-hold-invoice`).

MostroMessage<Order> _msg(Action action, {int? timestamp}) =>
    MostroMessage<Order>(
      action: action,
      id: 'order-1',
      timestamp: timestamp,
      payload: const Order(
        id: 'order-1',
        kind: OrderType.buy,
        status: Status.settledHoldInvoice,
        amount: 500,
        fiatCode: 'USD',
        fiatAmount: 50,
        paymentMethod: 'Cash',
      ),
    );

/// Replays a sequence of actions onto a fresh order state, mirroring how
/// RestoreService.restore() applies snapshot-derived messages via
/// OrderNotifier.updateStateFromMessage().
OrderState _replay(List<Action> actions) {
  OrderState state = OrderState(
    action: Action.newOrder,
    status: Status.pending,
    order: null,
  );
  for (final action in actions) {
    state = state.updateWith(_msg(action));
  }
  return state;
}

void main() {
  group('restoreHasFailedPayoutSignal', () {
    test('returns false for empty history', () {
      expect(restoreHasFailedPayoutSignal([]), isFalse);
    });

    test('returns true when payment-failed is present', () {
      expect(
        restoreHasFailedPayoutSignal([_msg(Action.paymentFailed, timestamp: 1)]),
        isTrue,
      );
    });

    test('returns true for a re-sent add-invoice (storage cleared on restore)',
        () {
      expect(
        restoreHasFailedPayoutSignal([_msg(Action.addInvoice, timestamp: 1)]),
        isTrue,
      );
    });

    test('returns true when add-invoice arrives after the hold was released',
        () {
      expect(
        restoreHasFailedPayoutSignal([
          _msg(Action.released, timestamp: 1),
          _msg(Action.addInvoice, timestamp: 2),
        ]),
        isTrue,
      );
    });

    test('returns false for an early add-invoice that precedes the release', () {
      // Happy path where the daemon re-sends full history: the only add-invoice
      // is the early waiting-buyer-invoice one, before the release.
      expect(
        restoreHasFailedPayoutSignal([
          _msg(Action.addInvoice, timestamp: 1),
          _msg(Action.released, timestamp: 2),
        ]),
        isFalse,
      );
    });

    test('returns false for a settled order with no failed-payout signal', () {
      expect(
        restoreHasFailedPayoutSignal([
          _msg(Action.holdInvoicePaymentSettled, timestamp: 1),
        ]),
        isFalse,
      );
    });
  });

  group('restore state rebuild for settled-hold-invoice + buyer', () {
    test(
        'failed payout replays to payment-failed + add-invoice (new-invoice prompt)',
        () {
      final state = _replay([Action.paymentFailed, Action.addInvoice]);

      expect(state.status, equals(Status.paymentFailed));
      expect(state.action, equals(Action.addInvoice));
    });

    test('happy path replays to settled-hold-invoice + released (paying sats)',
        () {
      final state = _replay([Action.released]);

      expect(state.status, equals(Status.settledHoldInvoice));
      expect(state.action, equals(Action.released));
    });
  });
}
