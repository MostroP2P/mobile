import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';

/// Drives the OrderState through the maker order-creation sequence when the
/// node has the anti-abuse bond enabled: submit (new-order/pending) →
/// pay-bond-invoice (PaymentRequest) → publication ack (new-order). Pure,
/// no mocks — locks the state machine behind the maker bond create flow.
void main() {
  // The daemon parks the order at WaitingMakerBond and asks the maker to pay a
  // bond first; the bolt11 arrives as a PaymentRequest with the bond amount.
  final bondInvoice = MostroMessage<PaymentRequest>(
    id: 'order-1',
    action: Action.payBondInvoice,
    payload: PaymentRequest(
      order: const Order(
        id: 'order-1',
        kind: OrderType.sell,
        status: Status.pending,
        amount: 300,
        fiatCode: 'CUP',
        fiatAmount: 200,
        paymentMethod: 'tttt',
      ),
      lnInvoice: 'lnbc3u1pexample',
    ),
  );

  // Once the bond locks the daemon publishes and acks with new-order.
  final publishedAck = MostroMessage<Order>(
    id: 'order-1',
    action: Action.newOrder,
    payload: const Order(
      id: 'order-1',
      kind: OrderType.sell,
      status: Status.pending,
      amount: 0,
      fiatCode: 'CUP',
      fiatAmount: 200,
      paymentMethod: 'tttt',
    ),
  );

  OrderState initial() => OrderState(
        action: Action.newOrder,
        status: Status.pending,
        order: null,
      );

  group('maker bond order-creation state sequence', () {
    test('pay-bond-invoice moves to the bond-waiting state and keeps the invoice',
        () {
      final updated = initial().updateWith(bondInvoice);

      expect(updated.status, equals(Status.waitingTakerBond));
      expect(updated.paymentRequest?.lnInvoice, equals('lnbc3u1pexample'));
    });

    test('post-bond new-order confirms the order back to pending', () {
      final confirmed = initial().updateWith(bondInvoice).updateWith(publishedAck);

      expect(confirmed.status, equals(Status.pending));
      expect(confirmed.order?.id, equals('order-1'));
    });
  });
}
