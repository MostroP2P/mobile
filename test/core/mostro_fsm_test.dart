import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/core/mostro_fsm.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';

void main() {
  group('MostroFSM.nextStatus', () {
    test('buyer taking a sell order moves to waiting-buyer-invoice', () {
      // Arrange
      const current = Status.pending;

      // Act
      final next = MostroFSM.nextStatus(current, Role.buyer, Action.takeSell);

      // Assert
      expect(next, Status.waitingBuyerInvoice);
    });

    test('seller taking a buy order moves to waiting-payment', () {
      final next = MostroFSM.nextStatus(
        Status.pending,
        Role.seller,
        Action.takeBuy,
      );

      expect(next, Status.waitingPayment);
    });

    test('buyer adding an invoice moves to waiting-payment', () {
      final next = MostroFSM.nextStatus(
        Status.waitingBuyerInvoice,
        Role.buyer,
        Action.addInvoice,
      );

      expect(next, Status.waitingPayment);
    });

    test('seller paying the hold invoice activates the order', () {
      final next = MostroFSM.nextStatus(
        Status.waitingPayment,
        Role.seller,
        Action.payInvoice,
      );

      expect(next, Status.active);
    });

    test('failed hold invoice payment moves to payment-failed for both roles',
        () {
      expect(
        MostroFSM.nextStatus(
          Status.waitingPayment,
          Role.seller,
          Action.paymentFailed,
        ),
        Status.paymentFailed,
      );
      expect(
        MostroFSM.nextStatus(
          Status.waitingPayment,
          Role.buyer,
          Action.paymentFailed,
        ),
        Status.paymentFailed,
      );
    });

    test('buyer can retry with a new invoice after payment-failed', () {
      final next = MostroFSM.nextStatus(
        Status.paymentFailed,
        Role.buyer,
        Action.addInvoice,
      );

      expect(next, Status.waitingPayment);
    });

    test('seller can retry the payment after payment-failed', () {
      final next = MostroFSM.nextStatus(
        Status.paymentFailed,
        Role.seller,
        Action.payInvoice,
      );

      expect(next, Status.active);
    });

    test('buyer marking fiat as sent moves an active order to fiat-sent', () {
      final next = MostroFSM.nextStatus(
        Status.active,
        Role.buyer,
        Action.fiatSent,
      );

      expect(next, Status.fiatSent);
    });

    test('seller releasing after fiat-sent settles the hold invoice', () {
      final next = MostroFSM.nextStatus(
        Status.fiatSent,
        Role.seller,
        Action.release,
      );

      expect(next, Status.settledHoldInvoice);
    });

    test('buyer sees hold invoice settled as settled-hold-invoice', () {
      final next = MostroFSM.nextStatus(
        Status.fiatSent,
        Role.buyer,
        Action.holdInvoicePaymentSettled,
      );

      expect(next, Status.settledHoldInvoice);
    });

    test('rating an active order as seller moves it to success', () {
      final next = MostroFSM.nextStatus(
        Status.active,
        Role.seller,
        Action.rate,
      );

      expect(next, Status.success);
    });

    test('rating a successful order keeps it in success', () {
      for (final role in [Role.buyer, Role.seller]) {
        expect(
          MostroFSM.nextStatus(Status.success, role, Action.rate),
          Status.success,
          reason: 'role $role should stay in success after rating',
        );
      }
    });

    test('cancel is accepted for both roles across all live statuses', () {
      const liveStatuses = [
        Status.pending,
        Status.waitingBuyerInvoice,
        Status.waitingPayment,
        Status.paymentFailed,
        Status.active,
      ];

      for (final status in liveStatuses) {
        for (final role in [Role.buyer, Role.seller]) {
          expect(
            MostroFSM.nextStatus(status, role, Action.cancel),
            Status.canceled,
            reason: '$role should be able to cancel from $status',
          );
        }
      }
    });

    test('disputeInitiatedByYou moves a fiat-sent order to dispute', () {
      for (final role in [Role.buyer, Role.seller]) {
        expect(
          MostroFSM.nextStatus(
            Status.fiatSent,
            role,
            Action.disputeInitiatedByYou,
          ),
          Status.dispute,
        );
      }
    });

    test('admin settling a dispute moves it to settled-by-admin', () {
      expect(
        MostroFSM.nextStatus(Status.dispute, Role.admin, Action.adminSettle),
        Status.settledByAdmin,
      );
      expect(
        MostroFSM.nextStatus(Status.dispute, Role.admin, Action.adminSettled),
        Status.settledByAdmin,
      );
    });

    test('admin canceling a dispute moves it to canceled-by-admin', () {
      expect(
        MostroFSM.nextStatus(Status.dispute, Role.admin, Action.adminCancel),
        Status.canceledByAdmin,
      );
      expect(
        MostroFSM.nextStatus(Status.dispute, Role.admin, Action.adminCanceled),
        Status.canceledByAdmin,
      );
    });

    test('non-admin roles cannot resolve a dispute', () {
      for (final role in [Role.buyer, Role.seller]) {
        expect(
          MostroFSM.nextStatus(Status.dispute, role, Action.adminSettle),
          isNull,
        );
      }
    });

    test('returns null for an unknown status', () {
      final next = MostroFSM.nextStatus(
        Status.expired,
        Role.buyer,
        Action.cancel,
      );

      expect(next, isNull);
    });

    test('returns null for an action not allowed in the current status', () {
      final next = MostroFSM.nextStatus(
        Status.pending,
        Role.buyer,
        Action.release,
      );

      expect(next, isNull);
    });

    test('canceled is a dead end for every role', () {
      for (final role in Role.values) {
        expect(MostroFSM.possibleActions(Status.canceled, role), isEmpty);
      }
    });
  });

  group('MostroFSM.possibleActions', () {
    test('lists exactly the actions a pending buyer may take', () {
      final actions = MostroFSM.possibleActions(Status.pending, Role.buyer);

      expect(
        actions,
        containsAll([Action.takeSell, Action.cancel, Action.dispute]),
      );
      expect(actions, hasLength(3));
    });

    test('lists exactly the actions a pending seller may take', () {
      final actions = MostroFSM.possibleActions(Status.pending, Role.seller);

      expect(
        actions,
        containsAll([Action.takeBuy, Action.cancel, Action.dispute]),
      );
      expect(actions, hasLength(3));
    });

    test('returns an empty list for an unmapped status', () {
      expect(MostroFSM.possibleActions(Status.expired, Role.buyer), isEmpty);
    });

    test('returns an empty list for admin in non-dispute statuses', () {
      expect(MostroFSM.possibleActions(Status.pending, Role.admin), isEmpty);
      expect(MostroFSM.possibleActions(Status.active, Role.admin), isEmpty);
    });

    test('every advertised action resolves to a non-null next status', () {
      const statuses = [
        Status.pending,
        Status.waitingBuyerInvoice,
        Status.waitingPayment,
        Status.paymentFailed,
        Status.active,
        Status.fiatSent,
        Status.settledHoldInvoice,
        Status.success,
        Status.dispute,
        Status.canceled,
      ];

      for (final status in statuses) {
        for (final role in Role.values) {
          for (final action in MostroFSM.possibleActions(status, role)) {
            expect(
              MostroFSM.nextStatus(status, role, action),
              isNotNull,
              reason: '$status/$role/$action must map to a status',
            );
          }
        }
      }
    });
  });

  group('MostroFSM role shortcut tables', () {
    test('buyer table exposes the pending take-sell transition', () {
      expect(
        MostroFSM.buyer[Status.pending]?[Action.takeSell],
        Status.waitingBuyerInvoice,
      );
    });

    test('buyer table treats fiat-sent as terminal', () {
      expect(MostroFSM.buyer[Status.fiatSent], isEmpty);
    });

    test('seller table lets the seller release after fiat-sent', () {
      expect(
        MostroFSM.seller[Status.fiatSent]?[Action.release],
        Status.settledHoldInvoice,
      );
    });

    test('admin table can release an active fiat-sent-ok order', () {
      expect(
        MostroFSM.admin[(Status.active, Action.fiatSentOk)]?[Action.release],
        Status.settledHoldInvoice,
      );
    });

    test('admin table can cancel and dispute an active fiat-sent-ok order', () {
      final table = MostroFSM.admin[(Status.active, Action.fiatSentOk)]!;

      expect(table[Action.cancel], Status.canceled);
      expect(table[Action.dispute], Status.dispute);
    });
  });
}
