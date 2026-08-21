import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/payment_request.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';

Order order({
  Status status = Status.active,
  int amount = 100000,
  int fiatAmount = 500,
  String fiatCode = 'USD',
  String paymentMethod = 'Bank A',
  int premium = 0,
}) =>
    Order(
      id: 'order-1',
      kind: OrderType.sell,
      status: status,
      amount: amount,
      fiatCode: fiatCode,
      fiatAmount: fiatAmount,
      paymentMethod: paymentMethod,
      premium: premium,
    );

MostroMessage<Order> orderMessage(Action action, Order payload) =>
    MostroMessage<Order>(action: action, id: 'order-1', payload: payload);

void main() {
  OrderState stateWith(Order tracked, {Status status = Status.active}) =>
      OrderState(action: Action.buyerTookOrder, status: status, order: tracked);

  // The fiat terms are what the buyer acts on: the trade screen renders the
  // payment method as the account to send money to. They are settled when the
  // order is taken and nothing renegotiates them.
  group('trade terms once the order is under way', () {
    test('a later payload cannot redirect the payment method', () {
      final state = stateWith(order(paymentMethod: 'Bank A'));

      final next = state.updateWith(orderMessage(
        Action.invoiceUpdated,
        order(paymentMethod: 'MULE LLC IBAN XX66'),
      ));

      expect(next.order!.paymentMethod, 'Bank A');
    });

    test('nor restate the fiat amount, currency or premium', () {
      final state = stateWith(order());

      final next = state.updateWith(orderMessage(
        Action.invoiceUpdated,
        order(fiatAmount: 5000, fiatCode: 'EUR', premium: 40),
      ));

      expect(next.order!.fiatAmount, 500);
      expect(next.order!.fiatCode, 'USD');
      expect(next.order!.premium, 0);
    });

    test('the sats amount is still free to move', () {
      // A market-price order has none until it is taken, and the node
      // resolves it then.
      final state = stateWith(order(amount: 0));

      final next = state.updateWith(
        orderMessage(Action.holdInvoicePaymentAccepted, order(amount: 250000)),
      );

      expect(next.order!.amount, 250000);
    });

    test('everything else on the payload still applies', () {
      final state = stateWith(order());

      final next = state.updateWith(orderMessage(
        Action.fiatSentOk,
        order(paymentMethod: 'MULE', status: Status.fiatSent),
      ));

      expect(next.order!.status, Status.fiatSent);
      expect(next.order!.paymentMethod, 'Bank A');
    });
  });

  group('while the order is still pending', () {
    test('terms are written freely', () {
      // They are being settled: the message that takes the order out of
      // pending is the one that fixes them.
      final state = stateWith(
        order(status: Status.pending, paymentMethod: 'Bank A'),
        status: Status.pending,
      );

      final next = state.updateWith(orderMessage(
        Action.buyerTookOrder,
        order(paymentMethod: 'Bank B', fiatAmount: 900),
      ));

      expect(next.order!.paymentMethod, 'Bank B');
      expect(next.order!.fiatAmount, 900);
    });

    test('the first tracked order is taken as given', () {
      final empty = OrderState(
        action: Action.newOrder,
        status: Status.pending,
        order: null,
      );

      final next = empty.updateWith(
        orderMessage(Action.newOrder, order(paymentMethod: 'Bank A')),
      );

      expect(next.order!.paymentMethod, 'Bank A');
    });
  });

  // The amount in a payment request is the figure for that payment — the hold
  // invoice is the order plus the seller's fee — so it was never the order.
  group('a payment request does not restate the order', () {
    test('its embedded order does not become the tracked one', () {
      final state = stateWith(order(amount: 100000, paymentMethod: 'Bank A'));

      final next = state.updateWith(MostroMessage<PaymentRequest>(
        action: Action.payInvoice,
        id: 'order-1',
        payload: PaymentRequest(
          order: order(amount: 100300, paymentMethod: 'MULE'),
          lnInvoice: 'lnbc1003u1example',
        ),
      ));

      expect(next.order!.amount, 100000);
      expect(next.order!.paymentMethod, 'Bank A');
    });

    test('but stays reachable for the screen that pays it', () {
      final state = stateWith(order(amount: 100000));

      final next = state.updateWith(MostroMessage<PaymentRequest>(
        action: Action.payInvoice,
        id: 'order-1',
        payload: PaymentRequest(
          order: order(amount: 100300),
          lnInvoice: 'lnbc1003u1example',
        ),
      ));

      expect(next.paymentRequest!.order!.amount, 100300);
      expect(next.paymentRequest!.lnInvoice, 'lnbc1003u1example');
    });
  });
}
