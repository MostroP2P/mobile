import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';

/// Tracked trade order with a real trade amount.
Order _trackedOrder() => const Order(
      id: 'order-1',
      kind: OrderType.sell,
      status: Status.active,
      amount: 500,
      fiatCode: 'CUP',
      fiatAmount: 333,
      paymentMethod: 'Saldo móvil',
    );

/// bond-slashed payload: a SmallOrder whose amount is the bond (not the trade)
/// and whose status is null on the wire (Order.fromJson defaults it to pending).
MostroMessage<Order> _bondSlashedMessage() => MostroMessage<Order>(
      action: Action.bondSlashed,
      payload: const Order(
        id: 'order-1',
        kind: OrderType.sell,
        amount: 1000,
        fiatCode: 'CUP',
        fiatAmount: 333,
        paymentMethod: 'Saldo móvil',
      ),
    );

void main() {
  group('bond-slashed does not overwrite the tracked order', () {
    test('preserves the current order status (not pending from payload)', () {
      final state = OrderState(
        status: Status.active,
        action: Action.holdInvoicePaymentAccepted,
        order: _trackedOrder(),
      );

      final updated = state.updateWith(_bondSlashedMessage());

      expect(updated.status, equals(Status.active));
    });

    test('keeps the tracked trade order instead of the bond SmallOrder', () {
      final state = OrderState(
        status: Status.active,
        action: Action.holdInvoicePaymentAccepted,
        order: _trackedOrder(),
      );

      final updated = state.updateWith(_bondSlashedMessage());

      expect(updated.order!.amount, equals(500));
      expect(updated.order!.id, equals('order-1'));
    });

    test('preserves a terminal status (canceled) and records the action', () {
      final state = OrderState(
        status: Status.canceled,
        action: Action.canceled,
        order: _trackedOrder(),
      );

      final updated = state.updateWith(_bondSlashedMessage());

      expect(updated.status, equals(Status.canceled));
      expect(updated.order!.amount, equals(500));
      expect(updated.action, equals(Action.bondSlashed));
    });
  });
}
