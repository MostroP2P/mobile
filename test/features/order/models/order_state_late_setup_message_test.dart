import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';

/// Messages that land after the trade moved past their phase are late copies
/// (relays replay newest-first, decryption is concurrent, and the wire
/// created_at has one-second resolution). Applying them used to move the
/// status back to a phase whose action table has no fiat-sent, release or
/// chat button, leaving the trade looking stuck until a dispute reset the
/// row, or reopen a terminal order.
Order _order(Status status) => Order(
      id: 'order-1',
      kind: OrderType.sell,
      status: status,
      amount: 495,
      fiatCode: 'CUP',
      fiatAmount: 333,
      paymentMethod: 'Saldo móvil',
    );

OrderState _state(Status status, Action action) => OrderState(
      status: status,
      action: action,
      order: _order(status),
    );

MostroMessage _message(Action action, {Status? status}) => MostroMessage(
      action: action,
      id: 'order-1',
      payload: status == null ? null : _order(status),
      timestamp: 1,
    );

void main() {
  group('late setup messages on an active trade', () {
    test('a late waiting-seller-to-pay keeps the buyer on active', () {
      // Arrange
      final active = _state(Status.active, Action.holdInvoicePaymentAccepted);

      // Act
      final next = active.updateWith(
        _message(Action.waitingSellerToPay, status: Status.waitingPayment),
      );

      // Assert
      expect(next.status, Status.active);
      expect(next.getActions(Role.buyer), contains(Action.fiatSent));
      expect(next.getActions(Role.buyer), contains(Action.sendDm));
    });

    test('a late waiting-buyer-invoice keeps the seller on active', () {
      final active = _state(Status.active, Action.buyerTookOrder);

      final next = active.updateWith(
        _message(Action.waitingBuyerInvoice,
            status: Status.waitingBuyerInvoice),
      );

      expect(next.status, Status.active);
      expect(next.getActions(Role.seller), contains(Action.sendDm));
    });

    test('a late buyer-took-order keeps the seller on fiat-sent', () {
      final fiatSent = _state(Status.fiatSent, Action.fiatSentOk);

      final next = fiatSent.updateWith(
        _message(Action.buyerTookOrder, status: Status.active),
      );

      expect(next.status, Status.fiatSent);
      expect(next.getActions(Role.seller), contains(Action.release));
    });

    test('a late hold-invoice-payment-accepted keeps a dispute open', () {
      final disputed = _state(Status.dispute, Action.disputeInitiatedByYou);

      final next = disputed.updateWith(
        _message(Action.holdInvoicePaymentAccepted, status: Status.active),
      );

      expect(next.status, Status.dispute);
      expect(next.action, Action.disputeInitiatedByYou);
    });
  });

  _lateCopiesOnLaterPhases();

  group('messages that are not late', () {
    test('the active-entry message still opens the active phase', () {
      final waiting = _state(Status.waitingPayment, Action.waitingSellerToPay);

      final next = waiting.updateWith(
        _message(Action.holdInvoicePaymentAccepted, status: Status.active),
      );

      expect(next.status, Status.active);
    });

    test('add-invoice after a failed payout is still applied', () {
      // Mostro reuses add-invoice to ask for a payout invoice, so it must not
      // be treated as a setup-phase leftover.
      final failed = _state(Status.paymentFailed, Action.paymentFailed);

      final next = failed.updateWith(_message(Action.addInvoice));

      expect(next.action, Action.addInvoice);
      expect(next.getActions(Role.buyer), contains(Action.addInvoice));
    });

    test('a republished order still returns to pending', () {
      final waiting = _state(Status.waitingPayment, Action.payInvoice);

      final next = waiting.updateWith(
        _message(Action.newOrder, status: Status.pending),
      );

      expect(next.status, Status.pending);
    });
  });
}

void _lateCopiesOnLaterPhases() {
  group('late copies on later phases', () {
    test('a same-second fiat-sent-ok does not undo a release', () {
      // The wire created_at has one-second resolution, so the tie falls back
      // to receive order; the transition guard must hold on its own.
      final released = _state(Status.settledHoldInvoice, Action.released);

      final next = released.updateWith(
        _message(Action.fiatSentOk, status: Status.fiatSent),
      );

      expect(next.status, Status.settledHoldInvoice);
      expect(next.action, Action.released);
    });

    test('a same-second released does not undo purchase-completed', () {
      final done = _state(Status.success, Action.purchaseCompleted);

      final next = done.updateWith(
        _message(Action.released, status: Status.settledHoldInvoice),
      );

      expect(next.status, Status.success);
      expect(next.getActions(Role.buyer), contains(Action.rate));
    });

    test('a late hold-invoice-payment-accepted keeps a cooperative cancel',
        () {
      final canceling = _state(
          Status.cooperativelyCanceled, Action.cooperativeCancelNoFiatByYou);

      final next = canceling.updateWith(
        _message(Action.holdInvoicePaymentAccepted, status: Status.active),
      );

      expect(next.status, Status.cooperativelyCanceled);
    });

    test('fiat-sent-ok is still applied while a cooperative cancel is pending',
        () {
      // The buyer can still complete the trade: same rank, not a move back.
      final canceling = _state(
          Status.cooperativelyCanceled, Action.cooperativeCancelNoFiatByPeer);

      final next = canceling.updateWith(
        _message(Action.fiatSentOk, status: Status.fiatSent),
      );

      expect(next.status, Status.fiatSent);
    });
  });

  group('late copies on terminal orders', () {
    for (final status in [
      Status.expired,
      Status.canceled,
      Status.success,
      Status.settledByAdmin,
    ]) {
      test('a late waiting-seller-to-pay does not reopen $status', () {
        final terminal = _state(status, Action.canceled);

        final next = terminal.updateWith(
          _message(Action.waitingSellerToPay, status: Status.waitingPayment),
        );

        expect(next.status, status);
      });

      test('a late hold-invoice-payment-accepted does not reopen $status',
          () {
        final terminal = _state(status, Action.canceled);

        final next = terminal.updateWith(
          _message(Action.holdInvoicePaymentAccepted, status: Status.active),
        );

        expect(next.status, status);
      });

      test('a late new-order does not reopen $status', () {
        final terminal = _state(status, Action.canceled);

        final next = terminal.updateWith(
          _message(Action.newOrder, status: Status.pending),
        );

        expect(next.status, status);
      });
    }
  });
}
