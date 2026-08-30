import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/payment_failed.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';

/// `OrderState.==` compares its `order` and `paymentFailed` payloads, but
/// those classes had identity equality only — so every replayed message
/// produced a "new" state and N rebuild cascades even when nothing changed.
void main() {
  Order order({int fiatAmount = 100}) => Order(
        id: 'o1',
        kind: OrderType.sell,
        status: Status.pending,
        amount: 0,
        fiatCode: 'VES',
        fiatAmount: fiatAmount,
        paymentMethod: 'face to face',
        premium: 1,
      );

  group('Order value equality', () {
    test('same field values compare equal', () {
      expect(order(), order());
      expect(order().hashCode, order().hashCode);
    });

    test('a differing field breaks equality', () {
      expect(order(), isNot(order(fiatAmount: 200)));
    });
  });

  group('PaymentFailed value equality', () {
    test('same values compare equal, different values do not', () {
      PaymentFailed pf(int attempts) => PaymentFailed(
            paymentAttempts: attempts,
            paymentRetriesInterval: 60,
          );
      expect(pf(3), pf(3));
      expect(pf(3), isNot(pf(4)));
    });
  });

  group('OrderState equality through payloads', () {
    test('states built from equal payloads compare equal', () {
      OrderState state() => OrderState(
            action: Action.newOrder,
            status: Status.pending,
            order: order(),
            paymentFailed: PaymentFailed(
              paymentAttempts: 1,
              paymentRetriesInterval: 30,
            ),
          );

      expect(state(), state(),
          reason: 'replaying an identical message must not produce a '
              '"different" state that fans out N rebuilds');
    });
  });
}
