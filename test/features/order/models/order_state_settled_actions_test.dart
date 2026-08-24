import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';

Order _settledOrder() => const Order(
      id: 'order-1',
      kind: OrderType.sell,
      status: Status.settledHoldInvoice,
      amount: 495,
      fiatCode: 'CUP',
      fiatAmount: 333,
      paymentMethod: 'Saldo móvil',
    );

OrderState _state(Status status, Action action) => OrderState(
      status: status,
      action: action,
      order: _settledOrder(),
    );

void main() {
  group('buyer actions once the order is settled', () {
    test('the invoice is offered while the payout is still on its way', () {
      final actions = _state(Status.settledHoldInvoice, Action.released)
          .getActions(Role.buyer);

      expect(actions, contains(Action.addInvoice));
    });

    test('the invoice is offered after the payment-failed notice', () {
      final actions = _state(Status.paymentFailed, Action.paymentFailed)
          .getActions(Role.buyer);

      expect(actions, contains(Action.addInvoice));
    });

    test('the invoice is offered when Mostro asks for a new one', () {
      final actions = _state(Status.paymentFailed, Action.addInvoice)
          .getActions(Role.buyer);

      expect(actions, contains(Action.addInvoice));
    });

    test('the invoice survives the invoice-updated ack', () {
      // Mostro acks the new invoice with invoice-updated and no payload, so the
      // status is kept and only the action changes. Without a row for it the
      // buyer would lose the button until the next payment-failed.
      for (final state in [
        _state(Status.paymentFailed, Action.invoiceUpdated),
        _state(Status.settledHoldInvoice, Action.invoiceUpdated),
      ]) {
        expect(state.getActions(Role.buyer), contains(Action.addInvoice),
            reason: '${state.status} / ${state.action}');
      }
    });

    test('the whole payout retry sequence keeps the invoice reachable', () {
      // released -> add-invoice (settled payload) -> invoice-updated ack.
      var state = _state(Status.settledHoldInvoice, Action.released);
      expect(state.getActions(Role.buyer), contains(Action.addInvoice));

      state = state.updateWith(MostroMessage<Order>(
        action: Action.addInvoice,
        payload: _settledOrder(),
      ));
      expect(state.status, equals(Status.paymentFailed));
      expect(state.getActions(Role.buyer), contains(Action.addInvoice));

      state = state.updateWith(MostroMessage<Order>(
        action: Action.invoiceUpdated,
      ));
      expect(state.status, equals(Status.paymentFailed));
      expect(state.getActions(Role.buyer), contains(Action.addInvoice));
    });

    test('cancel is never offered: Mostro rejects it on a settled order', () {
      for (final state in [
        _state(Status.settledHoldInvoice, Action.released),
        _state(Status.settledHoldInvoice, Action.addInvoice),
        _state(Status.paymentFailed, Action.addInvoice),
        _state(Status.paymentFailed, Action.paymentFailed),
        _state(Status.paymentFailed, Action.invoiceUpdated),
        _state(Status.settledHoldInvoice, Action.invoiceUpdated),
      ]) {
        expect(state.getActions(Role.buyer), isNot(contains(Action.cancel)),
            reason: '${state.status} / ${state.action}');
        expect(state.getActions(Role.seller), isNot(contains(Action.cancel)),
            reason: '${state.status} / ${state.action}');
      }
    });
  });
}
