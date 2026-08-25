import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';

/// add-invoice as Mostro sends it right after a take: the payload announces
/// the order moving into waiting-buyer-invoice.
MostroMessage<Order> _takeAddInvoiceMessage() => MostroMessage<Order>(
      action: Action.addInvoice,
      payload: const Order(
        id: 'order-1',
        kind: OrderType.sell,
        status: Status.waitingBuyerInvoice,
        amount: 500,
        fiatCode: 'CUP',
        fiatAmount: 333,
        paymentMethod: 'Saldo móvil',
      ),
    );

/// add-invoice as Mostro sends it when the payout failed: same action, but the
/// order is already settled, which is what tells the two cases apart.
MostroMessage<Order> _payoutRetryMessage() => MostroMessage<Order>(
      action: Action.addInvoice,
      payload: const Order(
        id: 'order-1',
        kind: OrderType.sell,
        status: Status.settledHoldInvoice,
        amount: 495,
        fiatCode: 'CUP',
        fiatAmount: 333,
        paymentMethod: 'Saldo móvil',
      ),
    );

void main() {
  group('add-invoice after a failed payout', () {
    test('is detected from the payload without the payment-failed notice', () {
      // The buyer never got the payment-failed DM: it is only sent on the first
      // failure and the app may have been closed, reinstalled or restored.
      final state = OrderState(
        status: Status.settledHoldInvoice,
        action: Action.released,
        order: _payoutRetryMessage().getPayload<Order>(),
      );

      final updated = state.updateWith(_payoutRetryMessage());

      expect(updated.status, equals(Status.paymentFailed));
    });

    test('is still detected when the payment-failed notice did arrive', () {
      final state = OrderState(
        status: Status.paymentFailed,
        action: Action.paymentFailed,
        order: _payoutRetryMessage().getPayload<Order>(),
      );

      final updated = state.updateWith(_payoutRetryMessage());

      expect(updated.status, equals(Status.paymentFailed));
    });

    test('does not hijack the add-invoice that follows a take', () {
      final state = OrderState(
        status: Status.pending,
        action: Action.newOrder,
        order: _takeAddInvoiceMessage().getPayload<Order>(),
      );

      final updated = state.updateWith(_takeAddInvoiceMessage());

      expect(updated.status, equals(Status.waitingBuyerInvoice));
    });
  });
}
