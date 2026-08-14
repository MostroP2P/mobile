import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';

/// Guards against forged or replayed admin resolutions.
///
/// `admin-settled` / `admin-canceled` / `admin-took-dispute` are only
/// legitimate as the outcome of an existing dispute. Applying them without
/// dispute evidence lets a counterparty (v1 intake) or a replayed message flip
/// a live trade to a terminal state and drive the resolution UI.

Order _testOrder({Status status = Status.active}) => Order(
      id: 'test-order-id',
      kind: OrderType.sell,
      status: status,
      amount: 50000,
      fiatCode: 'USD',
      fiatAmount: 500,
      paymentMethod: 'SEPA',
      premium: 0,
    );

/// A live trade with no dispute anywhere: the victim's state before the forgery.
OrderState _stateWithoutDispute({
  Status status = Status.fiatSent,
  Action action = Action.fiatSentOk,
}) {
  return OrderState(
    status: status,
    action: action,
    order: _testOrder(status: status),
    dispute: null,
  );
}

/// A trade with a real dispute under review: the legitimate precondition for
/// an admin resolution.
OrderState _stateWithDispute({String disputeStatus = 'in-progress'}) {
  return OrderState(
    status: Status.dispute,
    action: Action.disputeInitiatedByYou,
    order: _testOrder(status: Status.dispute),
    dispute: Dispute(
      disputeId: 'dispute-1',
      orderId: 'test-order-id',
      status: disputeStatus,
    ),
  );
}

MostroMessage _message(Action action, {Payload? payload}) {
  return MostroMessage(id: 'test-order-id', action: action, payload: payload);
}

const _adminPubkey =
    'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

void main() {
  group('Admin resolutions require dispute evidence', () {
    test('bare admin-canceled does not flip a fiat-sent order', () {
      final state = _stateWithoutDispute();

      final updated = state.updateWith(_message(Action.adminCanceled));

      expect(updated.status, equals(Status.fiatSent),
          reason: 'no dispute exists, so the resolution must not apply');
      expect(updated.action, equals(Action.fiatSentOk));
      expect(updated.dispute, isNull);
    });

    test('bare admin-settled does not flip a fiat-sent order', () {
      final state = _stateWithoutDispute();

      final updated = state.updateWith(_message(Action.adminSettled));

      expect(updated.status, equals(Status.fiatSent));
      expect(updated.action, equals(Action.fiatSentOk));
      expect(updated.dispute, isNull);
    });

    test('bare admin-took-dispute does not move an active order to dispute',
        () {
      final state = _stateWithoutDispute(
        status: Status.active,
        action: Action.holdInvoicePaymentAccepted,
      );

      final updated = state.updateWith(_message(Action.adminTookDispute));

      expect(updated.status, equals(Status.active));
      expect(updated.dispute, isNull);
    });

    test('a one-field dispute payload does not invent a resolved dispute', () {
      final state = _stateWithoutDispute(
        status: Status.active,
        action: Action.holdInvoicePaymentAccepted,
      );

      final updated = state.updateWith(
        _message(
          Action.adminCanceled,
          payload: Dispute(disputeId: 'attacker-chosen-id'),
        ),
      );

      expect(updated.status, equals(Status.active),
          reason: 'an attacker-supplied dispute id is not dispute evidence');
      expect(updated.dispute, isNull,
          reason: 'the dispute object must not be materialized from the wire');
    });

    test('a payload dispute cannot re-point a tracked dispute at another id',
        () {
      final state = _stateWithDispute();

      final updated = state.updateWith(
        _message(
          Action.adminCanceled,
          payload: Dispute(disputeId: 'attacker-chosen-id'),
        ),
      );

      expect(updated.dispute, isNotNull);
      expect(updated.dispute!.disputeId, equals('dispute-1'),
          reason: 'the tracked dispute id must survive the wire payload');
    });

    test('a bare dispute message is not evidence for the resolution behind it',
        () {
      // Two-step forgery: Action.dispute maps to Status.dispute without
      // carrying a Dispute, so the status alone must not authorize what
      // follows it.
      final disputed =
          _stateWithoutDispute().updateWith(_message(Action.dispute));

      expect(disputed.status, equals(Status.dispute));
      expect(disputed.dispute, isNull);

      for (final action in [Action.adminCanceled, Action.adminSettled]) {
        final resolved = disputed.updateWith(_message(action));

        expect(resolved.status, equals(Status.dispute),
            reason: '$action must not be applied on a status-only dispute');
        expect(resolved.dispute, isNull);
      }
    });

    test('dispute status without a tracked dispute object is not evidence', () {
      final state = OrderState(
        status: Status.dispute,
        action: Action.disputeInitiatedByPeer,
        order: _testOrder(status: Status.dispute),
        dispute: null,
      );

      final updated = state.updateWith(_message(Action.adminSettled));

      expect(updated.status, equals(Status.dispute),
          reason: 'only a tracked Dispute object authorizes a resolution');
    });

    test('admin-settled payload alone cannot fabricate a settled dispute', () {
      final state = _stateWithoutDispute();

      final updated = state.updateWith(
        _message(
          Action.adminSettled,
          payload: Dispute(disputeId: 'attacker-chosen-id'),
        ),
      );

      expect(updated.status, equals(Status.fiatSent));
      expect(updated.dispute, isNull);
    });
  });

  group('Rejected resolutions are reported so side effects can be dropped', () {
    test('reports rejection for admin actions with no dispute evidence', () {
      final state = _stateWithoutDispute();

      expect(state.rejectsAdminDisputeAction(Action.adminCanceled), isTrue);
      expect(state.rejectsAdminDisputeAction(Action.adminSettled), isTrue);
      expect(state.rejectsAdminDisputeAction(Action.adminTookDispute), isTrue);
    });

    test('reports no rejection when a dispute is under review', () {
      final state = _stateWithDispute();

      expect(state.rejectsAdminDisputeAction(Action.adminCanceled), isFalse);
      expect(state.rejectsAdminDisputeAction(Action.adminSettled), isFalse);
    });

    test('reports rejection once the dispute is already resolved', () {
      final state = _stateWithDispute(disputeStatus: 'resolved');

      expect(state.rejectsAdminDisputeAction(Action.adminSettled), isTrue,
          reason: 'replaying a resolution onto a settled dispute is rejected');
    });

    test('never reports rejection for non-admin actions', () {
      final state = _stateWithoutDispute();

      expect(state.rejectsAdminDisputeAction(Action.fiatSentOk), isFalse);
      expect(state.rejectsAdminDisputeAction(Action.canceled), isFalse);
      expect(state.rejectsAdminDisputeAction(Action.release), isFalse);
    });

    test('agrees with what updateWith actually does', () {
      // The predicate drives side-effect suppression, so it must not diverge
      // from the state machine it is meant to describe.
      final states = [
        _stateWithoutDispute(),
        _stateWithDispute(),
        _stateWithDispute(disputeStatus: 'resolved'),
        _stateWithDispute(disputeStatus: 'seller-refunded'),
      ];
      const adminActions = [
        Action.adminCanceled,
        Action.adminSettled,
        Action.adminTookDispute,
      ];

      for (final state in states) {
        for (final action in adminActions) {
          final rejected = state.rejectsAdminDisputeAction(action);
          final unchanged = identical(state.updateWith(_message(action)), state);
          expect(rejected, equals(unchanged),
              reason: 'predicate and updateWith disagree for $action on '
                  '${state.status}/${state.dispute?.status}');
        }
      }
    });
  });

  group('Legitimate admin resolutions still apply', () {
    test('admin-settled resolves an existing in-progress dispute', () {
      final state = _stateWithDispute();

      final updated = state.updateWith(_message(Action.adminSettled));

      expect(updated.status, equals(Status.settledByAdmin));
      expect(updated.action, equals(Action.adminSettled));
      expect(updated.dispute, isNotNull);
      expect(updated.dispute!.status, equals('resolved'));
      expect(updated.dispute!.action, equals('admin-settled'));
    });

    test('admin-canceled resolves an existing in-progress dispute', () {
      final state = _stateWithDispute();

      final updated = state.updateWith(_message(Action.adminCanceled));

      expect(updated.status, equals(Status.canceledByAdmin),
          reason: 'an admin cancelation is its own terminal state');
      expect(updated.action, equals(Action.adminCanceled));
      expect(updated.dispute, isNotNull);
      expect(updated.dispute!.status, equals('seller-refunded'));
      expect(updated.dispute!.action, equals('admin-canceled'));
    });

    test('admin-canceled is distinguishable from a plain cancelation', () {
      final adminCanceled =
          _stateWithDispute().updateWith(_message(Action.adminCanceled));
      final plainCanceled =
          _stateWithoutDispute().updateWith(_message(Action.canceled));

      expect(adminCanceled.status, equals(Status.canceledByAdmin));
      expect(plainCanceled.status, equals(Status.canceled));
      expect(adminCanceled.status, isNot(equals(plainCanceled.status)),
          reason: 'the user must be able to tell an admin resolution apart '
              'from a cancelation by either party');
    });

    test('admin-canceled keeps a terminal status', () {
      final updated =
          _stateWithDispute().updateWith(_message(Action.adminCanceled));

      expect(updated.status.isTerminal, isTrue);
    });

    test('admin-took-dispute assigns the admin on an existing dispute', () {
      final state = _stateWithDispute(disputeStatus: 'initiated');

      final updated = state.updateWith(
        _message(
          Action.adminTookDispute,
          payload: Peer(publicKey: _adminPubkey),
        ),
      );

      expect(updated.status, equals(Status.dispute));
      expect(updated.dispute, isNotNull);
      expect(updated.dispute!.status, equals('in-progress'));
      expect(updated.dispute!.adminPubkey, equals(_adminPubkey));
    });

  });
}
