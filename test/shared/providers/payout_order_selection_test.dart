import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';

/// Which message states what the buyer's payout invoice must be worth.
///
/// Several actions carry an Order payload and their `amount` does not mean the
/// same thing: `orders` (the restore reply) carries the order's gross, while
/// the payout request carries the gross minus the Mostro fee. Picking the
/// newest Order payload made the screen ask for an amount the node rejects
/// (#748).
void main() {
  const orderId = 'order-1';

  Order order(int amount) => Order(
        id: orderId,
        kind: OrderType.sell,
        status: Status.settledHoldInvoice,
        amount: amount,
        fiatCode: 'EUR',
        fiatAmount: 710,
        paymentMethod: 'SEPA instant',
      );

  MostroMessage<Order> message(Action action, int amount) =>
      MostroMessage<Order>(
        action: action,
        id: orderId,
        payload: order(amount),
      );

  group('latestPayoutMessage', () {
    // The history arrives newest first.
    test('ignores a restore reply newer than the payout request', () {
      final history = [
        message(Action.orders, 937952),
        message(Action.addInvoice, 935138),
        message(Action.buyerTookOrder, 940766),
      ];

      expect(latestPayoutMessage(history)?.getPayload<Order>()?.amount, 935138);
    });

    test('accepts the payout confirmation too', () {
      final history = [
        message(Action.orders, 937952),
        message(Action.holdInvoicePaymentAccepted, 935138),
      ];

      expect(latestPayoutMessage(history)?.getPayload<Order>()?.amount, 935138);
    });

    test('prefers the newest of several payout messages', () {
      final history = [
        message(Action.addInvoice, 935138),
        message(Action.addInvoice, 111111),
      ];

      expect(latestPayoutMessage(history)?.getPayload<Order>()?.amount, 935138);
    });

    test('returns null when no message states the payout amount', () {
      final history = [
        message(Action.orders, 937952),
        message(Action.buyerTookOrder, 940766),
        message(Action.payInvoice, 940766),
      ];

      // A fresh install that only ran a restore has no payout message, and a
      // wrong amount is worse than none: the caller asks for an amountless
      // invoice instead.
      expect(latestPayoutMessage(history), isNull);
    });

    test('skips a payout action whose payload is not an order', () {
      final history = <MostroMessage>[
        MostroMessage<Payload>(action: Action.addInvoice, id: orderId),
        message(Action.addInvoice, 935138),
      ];

      expect(latestPayoutMessage(history)?.getPayload<Order>()?.amount, 935138);
    });
  });
}
