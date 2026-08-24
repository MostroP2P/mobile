import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/features/restore/restore_manager.dart';

/// Regression coverage for issue #615: restoring an order that Mostro reports
/// as `settled-hold-invoice` after a failed Lightning payout must land on the
/// new-invoice prompt (`add-invoice` + `payment-failed`), not "paying sats"
/// (`released` + `settled-hold-invoice`).

MostroMessage<Order> _msg(
  Action action, {
  int? timestamp,
  Status payloadStatus = Status.settledHoldInvoice,
}) =>
    MostroMessage<Order>(
      action: action,
      id: 'order-1',
      timestamp: timestamp,
      payload: Order(
        id: 'order-1',
        kind: OrderType.buy,
        status: payloadStatus,
        amount: 500,
        fiatCode: 'USD',
        fiatAmount: 50,
        paymentMethod: 'Cash',
      ),
    );

/// The payout request Mostro sends after a failed payment: `add-invoice`
/// carrying a settled order.
MostroMessage<Order> _payoutAddInvoice({int? timestamp}) =>
    _msg(Action.addInvoice, timestamp: timestamp);

/// The `add-invoice` that opens the normal buyer flow, before any settlement.
MostroMessage<Order> _earlyAddInvoice({int? timestamp}) => _msg(
      Action.addInvoice,
      timestamp: timestamp,
      payloadStatus: Status.waitingBuyerInvoice,
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

Future<({Action action, int timestamp})> _plan({
  required List<MostroMessage> stored,
  Action snapshotAction = Action.released,
  int snapshotTimestamp = 100,
  Status status = Status.settledHoldInvoice,
  Role? role = Role.buyer,
  void Function()? onLoad,
}) =>
    restoreReplayPlan(
      snapshotAction: snapshotAction,
      snapshotTimestamp: snapshotTimestamp,
      status: status,
      role: role,
      loadStoredMessages: () async {
        onLoad?.call();
        return stored;
      },
    );

void main() {
  group('restoreHasFailedPayoutSignal', () {
    test('returns false for empty history', () {
      expect(restoreHasFailedPayoutSignal([]), isFalse);
    });

    // Mostro sends payment-failed on the first failed payout only, so it is
    // definitive when present but cannot be required.
    test('returns true when payment-failed is present', () {
      expect(
        restoreHasFailedPayoutSignal([
          _msg(Action.paymentFailed, timestamp: 1),
        ]),
        isTrue,
      );
    });

    // The payout add-invoice is told apart from the early one by its payload
    // status, the same discriminator OrderState.updateWith uses, so a partial
    // or out-of-order relay-replayed history cannot fool it either way.
    test('returns true for an add-invoice carrying a settled order', () {
      expect(
        restoreHasFailedPayoutSignal([_payoutAddInvoice(timestamp: 1)]),
        isTrue,
      );
    });

    test('returns true for a payout add-invoice with no release in history',
        () {
      expect(
        restoreHasFailedPayoutSignal([_payoutAddInvoice(timestamp: 1)]),
        isTrue,
      );
    });

    test('returns false for the early waiting-buyer-invoice add-invoice', () {
      expect(
        restoreHasFailedPayoutSignal([
          _earlyAddInvoice(timestamp: 1),
          _msg(Action.released, timestamp: 2),
        ]),
        isFalse,
      );
    });

    // Partial happy-path history: the relay delivered the early add-invoice but
    // not the release yet. Ordering alone would misread this as a failed payout.
    test('returns false for a lone early add-invoice with no release yet', () {
      expect(
        restoreHasFailedPayoutSignal([_earlyAddInvoice(timestamp: 1)]),
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

  group('restoreReplayPlan', () {
    test('replays add-invoice for a buyer whose payout failed', () async {
      final plan = await _plan(stored: [_payoutAddInvoice(timestamp: 1)]);

      expect(plan.action, equals(Action.addInvoice));
    });

    test('keeps the snapshot action for a buyer with no failed payout',
        () async {
      final plan = await _plan(
        stored: [_msg(Action.holdInvoicePaymentSettled, timestamp: 1)],
      );

      expect(plan.action, equals(Action.released));
      expect(plan.timestamp, equals(100));
    });

    // The seller never sees the payout prompt: settled-hold-invoice means the
    // hold was settled and the trade is over for them.
    test('keeps the snapshot action for a seller', () async {
      var loaded = false;
      final plan = await _plan(
        stored: [_payoutAddInvoice(timestamp: 1)],
        role: Role.seller,
        onLoad: () => loaded = true,
      );

      expect(plan.action, equals(Action.released));
      expect(loaded, isFalse, reason: 'history is only read when it can matter');
    });

    test('keeps the snapshot action for another status', () async {
      var loaded = false;
      final plan = await _plan(
        stored: [_payoutAddInvoice(timestamp: 1)],
        status: Status.active,
        snapshotAction: Action.buyerTookOrder,
        onLoad: () => loaded = true,
      );

      expect(plan.action, equals(Action.buyerTookOrder));
      expect(loaded, isFalse, reason: 'history is only read when it can matter');
    });

    // A later OrderNotifier.sync() replays storage sorted by timestamp, so the
    // replayed add-invoice has to outrank every message already there or an
    // older released would win and drag the buyer back to "paying sats".
    test('stamps the replay after the latest stored message', () async {
      final plan = await _plan(
        stored: [
          _msg(Action.released, timestamp: 900),
          _payoutAddInvoice(timestamp: 950),
        ],
      );

      expect(plan.timestamp, equals(951));
    });

    test('never stamps the replay before the snapshot timestamp', () async {
      final plan = await _plan(
        stored: [_payoutAddInvoice(timestamp: 5)],
        snapshotTimestamp: 100,
      );

      expect(plan.timestamp, equals(101));
    });

    test('tolerates stored messages with no timestamp', () async {
      final plan = await _plan(stored: [_payoutAddInvoice()]);

      expect(plan.action, equals(Action.addInvoice));
      expect(plan.timestamp, equals(101));
    });
  });

  group('restore state rebuild for settled-hold-invoice + buyer', () {
    test('failed payout replays to payment-failed + add-invoice '
        '(new-invoice prompt)', () {
      final state = _replay([Action.addInvoice]);

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
