import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';

/// An invoice belongs to the take cycle that produced it. Mostro cancels the
/// bond and escrow hold invoices node-side when a cycle ends, so a bolt11 kept
/// across a cancel is unpayable (INCORRECT_PAYMENT_DETAILS) — and the bond
/// screen rendering the previous cycle's escrow invoice is what made an order
/// untakeable in the first place.
void main() {
  Order orderPayload({Status status = Status.pending}) => Order(
        id: 'order-1',
        kind: OrderType.buy,
        status: status,
        amount: 16558,
        fiatCode: 'EUR',
        fiatAmount: 10,
        paymentMethod: 'prueba',
      );

  MostroMessage<PaymentRequest> invoiceMessage(
    Action action,
    String bolt11, {
    int amount = 16558,
  }) =>
      MostroMessage<PaymentRequest>(
        id: 'order-1',
        action: action,
        payload: PaymentRequest(
          order: orderPayload(),
          lnInvoice: bolt11,
        ),
        timestamp: amount,
      );

  MostroMessage<Order> orderMessage(Action action, Status status) =>
      MostroMessage<Order>(
        id: 'order-1',
        action: action,
        payload: orderPayload(status: status),
      );

  OrderState initial() => OrderState(
        action: Action.newOrder,
        status: Status.pending,
        order: null,
      );

  group('take cycle boundaries', () {
    test('the bond invoice survives inside its own cycle', () {
      final state =
          initial().updateWith(invoiceMessage(Action.payBondInvoice, 'lnbcbond'));

      expect(state.status, Status.waitingTakerBond);
      expect(state.paymentRequest?.lnInvoice, 'lnbcbond');
    });

    test('cancelling the take drops the escrow invoice', () {
      final state = initial()
          .updateWith(invoiceMessage(Action.payBondInvoice, 'lnbcbond'))
          .updateWith(invoiceMessage(Action.payInvoice, 'lnbcescrow'))
          .updateWith(orderMessage(Action.canceled, Status.canceled));

      expect(state.status, Status.canceled);
      expect(state.paymentRequest, isNull);
    });

    test('a republish back to pending drops the escrow invoice', () {
      final state = initial()
          .updateWith(invoiceMessage(Action.payInvoice, 'lnbcescrow'))
          .updateWith(orderMessage(Action.newOrder, Status.pending));

      expect(state.status, Status.pending);
      expect(state.paymentRequest, isNull);
    });

    test('the invoice of the next cycle is not swallowed by the cleanup', () {
      // Republished back to the book, then taken again: the bond invoice of
      // the new cycle arrives on a state the cleanup just emptied.
      final state = initial()
          .updateWith(invoiceMessage(Action.payInvoice, 'lnbcescrow'))
          .updateWith(orderMessage(Action.newOrder, Status.pending))
          .updateWith(invoiceMessage(Action.payBondInvoice, 'lnbcbond2'));

      expect(state.status, Status.waitingTakerBond);
      expect(state.paymentRequest?.lnInvoice, 'lnbcbond2');
    });
  });

  group('endsTradeCycle', () {
    test('covers every status in which Mostro voids the cycle invoices', () {
      for (final status in [
        Status.pending,
        Status.canceled,
        Status.canceledByAdmin,
        Status.cooperativelyCanceled,
        Status.expired,
      ]) {
        expect(OrderState.endsTradeCycle(status), isTrue, reason: '$status');
      }

      for (final status in [
        Status.waitingTakerBond,
        Status.waitingPayment,
        Status.waitingBuyerInvoice,
        Status.active,
        Status.fiatSent,
        Status.success,
      ]) {
        expect(OrderState.endsTradeCycle(status), isFalse, reason: '$status');
      }
    });
  });

  group('wouldRejectAsStale', () {
    test('flags the first message of the take that follows a cancel', () {
      final canceled =
          initial().updateWith(orderMessage(Action.canceled, Status.canceled));

      // A cancelled order outranks every waiting phase, so without the
      // new-cycle reset in OrderNotifier.sync the retake would be dropped.
      expect(
        canceled.wouldRejectAsStale(
            invoiceMessage(Action.payBondInvoice, 'lnbcbond2')),
        isTrue,
      );
    });

    test('does not flag a forward move inside the cycle', () {
      final bond =
          initial().updateWith(invoiceMessage(Action.payBondInvoice, 'lnbcbond'));

      expect(
        bond.wouldRejectAsStale(invoiceMessage(Action.payInvoice, 'lnbcescrow')),
        isFalse,
      );
    });
  });

  group('replaying the persisted history of a retaken order', () {
    // Mirrors the loop in OrderNotifier.sync: a message that only looks stale
    // because the previous cycle ended restarts the replay.
    OrderState replay(List<MostroMessage> messages) {
      var current = initial();
      for (final message in messages) {
        if (OrderState.endsTradeCycle(current.status) &&
            current.wouldRejectAsStale(message)) {
          current = OrderState(
            status: Status.pending,
            action: Action.newOrder,
            order: current.order,
          );
        }
        current = current.updateWith(message);
      }
      return current;
    }

    test('ends on the new bond invoice, never the cancelled escrow one', () {
      final state = replay([
        invoiceMessage(Action.payBondInvoice, 'lnbcbond'),
        invoiceMessage(Action.payInvoice, 'lnbcescrow'),
        orderMessage(Action.waitingBuyerInvoice, Status.waitingBuyerInvoice),
        orderMessage(Action.canceled, Status.canceled),
        invoiceMessage(Action.payBondInvoice, 'lnbcbond2'),
      ]);

      expect(state.action, Action.payBondInvoice);
      expect(state.status, Status.waitingTakerBond);
      expect(state.paymentRequest?.lnInvoice, 'lnbcbond2');
    });

    test('a history that ends on the cancel keeps no invoice at all', () {
      final state = replay([
        invoiceMessage(Action.payBondInvoice, 'lnbcbond'),
        invoiceMessage(Action.payInvoice, 'lnbcescrow'),
        orderMessage(Action.canceled, Status.canceled),
      ]);

      expect(state.status, Status.canceled);
      expect(state.paymentRequest, isNull);
    });
  });
}
