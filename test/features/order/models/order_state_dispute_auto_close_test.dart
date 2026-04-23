import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';

/// Helper to create a minimal Order for testing.
Order _testOrder() => const Order(
      id: 'test-order-id',
      kind: OrderType.buy,
      status: Status.active,
      fiatCode: 'USD',
      fiatAmount: 100,
      paymentMethod: 'cash',
    );

/// Helper to create an OrderState with an in-progress dispute.
OrderState _stateWithDispute({String disputeStatus = 'in-progress'}) {
  return OrderState(
    status: Status.dispute,
    action: Action.disputeInitiatedByYou,
    order: _testOrder(),
    dispute: Dispute(
      disputeId: 'dispute-1',
      orderId: 'test-order-id',
      status: disputeStatus,
    ),
  );
}

/// Helper to create a MostroMessage with a given action and no payload.
MostroMessage _message(Action action) {
  return MostroMessage(action: action);
}

void main() {
  group('Dispute auto-close on terminal state', () {
    test('auto-closes dispute to user-completed when status reaches success',
        () {
      final state = _stateWithDispute();

      final updated = state.updateWith(_message(Action.purchaseCompleted));

      expect(updated.dispute, isNotNull);
      expect(updated.dispute!.status, equals('closed'));
      expect(updated.dispute!.action, equals('user-completed'));
      expect(updated.status, equals(Status.success));
    });

    test(
        'auto-closes dispute to user-completed when status reaches settledHoldInvoice',
        () {
      final state = _stateWithDispute();

      final updated = state.updateWith(_message(Action.released));

      expect(updated.dispute, isNotNull);
      expect(updated.dispute!.status, equals('closed'));
      expect(updated.dispute!.action, equals('user-completed'));
      expect(updated.status, equals(Status.settledHoldInvoice));
    });

    test(
        'auto-closes dispute to cooperative-cancel when cooperativeCancelAccepted',
        () {
      final state = _stateWithDispute();

      final updated =
          state.updateWith(_message(Action.cooperativeCancelAccepted));

      expect(updated.dispute, isNotNull);
      expect(updated.dispute!.status, equals('closed'));
      expect(updated.dispute!.action, equals('cooperative-cancel'));
      expect(updated.status, equals(Status.canceled));
    });

    test('does NOT overwrite already-resolved dispute', () {
      final state = _stateWithDispute(disputeStatus: 'resolved');

      final updated = state.updateWith(_message(Action.purchaseCompleted));

      expect(updated.dispute, isNotNull);
      expect(updated.dispute!.status, equals('resolved'));
      // action should remain unchanged (null in this case)
      expect(updated.dispute!.action, isNull);
    });

    test('does NOT overwrite already-closed dispute (idempotency)', () {
      final state = OrderState(
        status: Status.dispute,
        action: Action.disputeInitiatedByYou,
        order: _testOrder(),
        dispute: Dispute(
          disputeId: 'dispute-1',
          orderId: 'test-order-id',
          status: 'closed',
          action: 'user-completed',
        ),
      );

      final updated = state.updateWith(_message(Action.purchaseCompleted));

      expect(updated.dispute, isNotNull);
      expect(updated.dispute!.status, equals('closed'));
      expect(updated.dispute!.action, equals('user-completed'));
    });

    test('does NOT overwrite seller-refunded dispute', () {
      final state = _stateWithDispute(disputeStatus: 'seller-refunded');

      final updated = state.updateWith(_message(Action.purchaseCompleted));

      expect(updated.dispute, isNotNull);
      expect(updated.dispute!.status, equals('seller-refunded'));
    });

    test(
        'does NOT auto-close on cooperativeCancelInitiatedByYou (pending state)',
        () {
      final state = _stateWithDispute();

      final updated =
          state.updateWith(_message(Action.cooperativeCancelInitiatedByYou));

      expect(updated.dispute, isNotNull);
      expect(updated.dispute!.status, equals('in-progress'));
    });

    test(
        'does NOT auto-close on cooperativeCancelInitiatedByPeer (pending state)',
        () {
      final state = _stateWithDispute();

      final updated =
          state.updateWith(_message(Action.cooperativeCancelInitiatedByPeer));

      expect(updated.dispute, isNotNull);
      expect(updated.dispute!.status, equals('in-progress'));
    });

    test('does NOT auto-close on admin-canceled action', () {
      final state = _stateWithDispute();

      final updated = state.updateWith(_message(Action.adminCanceled));

      expect(updated.dispute, isNotNull);
      // adminCanceled sets dispute to seller-refunded via the admin handler
      expect(updated.dispute!.status, equals('seller-refunded'));
      expect(updated.dispute!.action, equals('admin-canceled'));
    });

    test('auto-close preserves dispute ID and other fields', () {
      final state = OrderState(
        status: Status.dispute,
        action: Action.disputeInitiatedByYou,
        order: _testOrder(),
        dispute: Dispute(
          disputeId: 'dispute-42',
          orderId: 'order-99',
          status: 'in-progress',
          adminPubkey: 'admin-key-123',
        ),
      );

      final updated = state.updateWith(_message(Action.purchaseCompleted));

      expect(updated.dispute!.disputeId, equals('dispute-42'));
      expect(updated.dispute!.orderId, equals('order-99'));
      expect(updated.dispute!.adminPubkey, equals('admin-key-123'));
      expect(updated.dispute!.status, equals('closed'));
      expect(updated.dispute!.action, equals('user-completed'));
    });

    test('no dispute present: no crash on terminal state', () {
      final state = OrderState(
        status: Status.active,
        action: Action.holdInvoicePaymentAccepted,
        order: _testOrder(),
      );

      final updated = state.updateWith(_message(Action.purchaseCompleted));

      expect(updated.dispute, isNull);
      expect(updated.status, equals(Status.success));
    });
  });

  group('Cooperative cancel action remapping', () {
    test('remaps cooperativeCancelInitiatedByYou to NoFiat when from active',
        () {
      final state = OrderState(
        status: Status.active,
        action: Action.holdInvoicePaymentAccepted,
        order: _testOrder(),
      );

      final updated = state
          .updateWith(_message(Action.cooperativeCancelInitiatedByYou));

      expect(updated.status, equals(Status.cooperativelyCanceled));
      expect(
          updated.action, equals(Action.cooperativeCancelNoFiatByYou));
      expect(updated.fiatWasSent, isFalse);
    });

    test(
        'remaps cooperativeCancelInitiatedByPeer to NoFiat when from active',
        () {
      final state = OrderState(
        status: Status.active,
        action: Action.holdInvoicePaymentAccepted,
        order: _testOrder(),
      );

      final updated = state
          .updateWith(_message(Action.cooperativeCancelInitiatedByPeer));

      expect(updated.status, equals(Status.cooperativelyCanceled));
      expect(
          updated.action, equals(Action.cooperativeCancelNoFiatByPeer));
      expect(updated.fiatWasSent, isFalse);
    });

    test(
        'remaps cooperativeCancelInitiatedByYou to FiatSent when from fiatSent',
        () {
      final state = OrderState(
        status: Status.fiatSent,
        action: Action.fiatSentOk,
        order: _testOrder(),
        fiatWasSent: true,
      );

      final updated = state
          .updateWith(_message(Action.cooperativeCancelInitiatedByYou));

      expect(updated.status, equals(Status.cooperativelyCanceled));
      expect(updated.action,
          equals(Action.cooperativeCancelFiatSentByYou));
      expect(updated.fiatWasSent, isTrue);
    });

    test(
        'remaps cooperativeCancelInitiatedByPeer to FiatSent when from fiatSent',
        () {
      final state = OrderState(
        status: Status.fiatSent,
        action: Action.fiatSentOk,
        order: _testOrder(),
        fiatWasSent: true,
      );

      final updated = state
          .updateWith(_message(Action.cooperativeCancelInitiatedByPeer));

      expect(updated.status, equals(Status.cooperativelyCanceled));
      expect(updated.action,
          equals(Action.cooperativeCancelFiatSentByPeer));
      expect(updated.fiatWasSent, isTrue);
    });

    test('fiatWasSent is set when fiatSent action is processed', () {
      final state = OrderState(
        status: Status.active,
        action: Action.holdInvoicePaymentAccepted,
        order: _testOrder(),
      );

      expect(state.fiatWasSent, isFalse);

      final updated = state.updateWith(_message(Action.fiatSentOk));

      expect(updated.fiatWasSent, isTrue);
    });

    test(
        'remaps to FiatSent from dispute when fiatWasSent was set earlier',
        () {
      // Simulate: active → fiatSent → dispute → cooperativeCancel
      final state = OrderState(
        status: Status.dispute,
        action: Action.disputeInitiatedByPeer,
        order: _testOrder(),
        fiatWasSent: true,
        dispute: Dispute(
          disputeId: 'dispute-1',
          orderId: 'test-order-id',
          status: 'in-progress',
        ),
      );

      final updated = state
          .updateWith(_message(Action.cooperativeCancelInitiatedByPeer));

      expect(updated.status, equals(Status.cooperativelyCanceled));
      expect(updated.action,
          equals(Action.cooperativeCancelFiatSentByPeer));
      expect(updated.fiatWasSent, isTrue);
    });

    test('remaps to NoFiat from dispute when fiatWasSent was never set',
        () {
      // Simulate: active → dispute → cooperativeCancel (no fiat sent)
      final state = OrderState(
        status: Status.dispute,
        action: Action.disputeInitiatedByPeer,
        order: _testOrder(),
        dispute: Dispute(
          disputeId: 'dispute-1',
          orderId: 'test-order-id',
          status: 'in-progress',
        ),
      );

      final updated = state
          .updateWith(_message(Action.cooperativeCancelInitiatedByYou));

      expect(updated.status, equals(Status.cooperativelyCanceled));
      expect(
          updated.action, equals(Action.cooperativeCancelNoFiatByYou));
      expect(updated.fiatWasSent, isFalse);
    });

    test('fiatWasSent persists through multiple state transitions', () {
      var state = OrderState(
        status: Status.active,
        action: Action.holdInvoicePaymentAccepted,
        order: _testOrder(),
      );

      // Process fiatSent
      state = state.updateWith(_message(Action.fiatSentOk));
      expect(state.fiatWasSent, isTrue);

      // Transition to dispute
      state = state.updateWith(_message(Action.disputeInitiatedByPeer));
      expect(state.fiatWasSent, isTrue);

      // Cooperative cancel from dispute
      state = state
          .updateWith(_message(Action.cooperativeCancelInitiatedByPeer));
      expect(state.fiatWasSent, isTrue);
      expect(state.action,
          equals(Action.cooperativeCancelFiatSentByPeer));
    });
  });

  group('DisputeData.getLocalizedDescription delegation', () {
    test('DisputeDescriptionKey maps closed to resolved', () {
      final dispute = Dispute(
        disputeId: 'dispute-1',
        status: 'closed',
        action: 'user-completed',
      );

      final data = DisputeData.fromDispute(dispute);

      expect(data.descriptionKey, equals(DisputeDescriptionKey.resolved));
      expect(data.action, equals('user-completed'));
    });

    test('DisputeDescriptionKey maps closed with cooperative-cancel', () {
      final dispute = Dispute(
        disputeId: 'dispute-1',
        status: 'closed',
        action: 'cooperative-cancel',
      );

      final data = DisputeData.fromDispute(dispute);

      expect(data.descriptionKey, equals(DisputeDescriptionKey.resolved));
      expect(data.action, equals('cooperative-cancel'));
    });

    test(
        'DisputeDescriptionKey for resolved status without action falls through',
        () {
      final dispute = Dispute(
        disputeId: 'dispute-1',
        status: 'resolved',
      );

      final data = DisputeData.fromDispute(dispute);

      expect(data.descriptionKey, equals(DisputeDescriptionKey.resolved));
      expect(data.action, isNull);
    });
  });
}
