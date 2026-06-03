import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/shared/utils/bond_cancel_helpers.dart';

const _graceMs = 60 * 1000;
const _now = 1700000000000;

MostroMessage _msg(Action action, {int? timestamp}) =>
    MostroMessage(action: action, id: 'order-1', timestamp: timestamp);

void main() {
  group('shouldDeferBondCancelDeletion', () {
    test('defers only for a bonded order the user did NOT cancel', () {
      // The single timeout-slash case where a bond-slashed notice may follow.
      expect(
        shouldDeferBondCancelDeletion(userInitiated: false, hadBond: true),
        isTrue,
      );
    });

    test('voluntary cancel of a bonded order deletes immediately', () {
      expect(
        shouldDeferBondCancelDeletion(userInitiated: true, hadBond: true),
        isFalse,
      );
    });

    test('non-bonded cancel always deletes immediately', () {
      expect(
        shouldDeferBondCancelDeletion(userInitiated: false, hadBond: false),
        isFalse,
      );
      expect(
        shouldDeferBondCancelDeletion(userInitiated: true, hadBond: false),
        isFalse,
      );
    });
  });

  group('reconcileBondCancelAction', () {
    BondCancelReconcileAction reconcile({
      bool sessionExists = true,
      bool hadBond = true,
      bool bondSlashedReceived = false,
      int latestCanceledTimestamp = _now - _graceMs - 1, // elapsed by default
    }) =>
        reconcileBondCancelAction(
          sessionExists: sessionExists,
          hadBond: hadBond,
          bondSlashedReceived: bondSlashedReceived,
          latestCanceledTimestamp: latestCanceledTimestamp,
          nowMs: _now,
          graceWindowMs: _graceMs,
        );

    test('no-op when the session is already gone', () {
      expect(reconcile(sessionExists: false), BondCancelReconcileAction.none);
    });

    test('no-op when the order had no bond (deleted live, never deferred)', () {
      expect(reconcile(hadBond: false), BondCancelReconcileAction.none);
    });

    test('deletes now when the grace window has already elapsed', () {
      expect(
        reconcile(latestCanceledTimestamp: _now - _graceMs - 1),
        BondCancelReconcileAction.deleteNow,
      );
    });

    test('deletes now when bond-slashed already arrived, even if recent', () {
      expect(
        reconcile(
          bondSlashedReceived: true,
          latestCanceledTimestamp: _now - 1000, // well within the window
        ),
        BondCancelReconcileAction.deleteNow,
      );
    });

    test('deletes now when there is no canceled timestamp (defensive)', () {
      expect(
        reconcile(latestCanceledTimestamp: 0),
        BondCancelReconcileAction.deleteNow,
      );
    });

    test('re-arms when within the grace window (quick restart)', () {
      expect(
        reconcile(latestCanceledTimestamp: _now - 5000), // 5s ago, window open
        BondCancelReconcileAction.rearm,
      );
    });

    test('deletes now exactly at the window boundary', () {
      expect(
        reconcile(latestCanceledTimestamp: _now - _graceMs), // elapsed == grace
        BondCancelReconcileAction.deleteNow,
      );
    });
  });

  group('latestCanceledTimestamp', () {
    test('returns 0 when there is no canceled message', () {
      expect(
        latestCanceledTimestamp([
          _msg(Action.payBondInvoice, timestamp: 10),
          _msg(Action.addInvoice, timestamp: 20),
        ]),
        0,
      );
    });

    test('picks the newest canceled timestamp regardless of order', () {
      expect(
        latestCanceledTimestamp([
          _msg(Action.canceled, timestamp: 300),
          _msg(Action.payBondInvoice, timestamp: 100),
          _msg(Action.canceled, timestamp: 500),
          _msg(Action.canceled, timestamp: 200),
        ]),
        500,
      );
    });

    test('treats a null timestamp as zero without throwing', () {
      expect(
        latestCanceledTimestamp([_msg(Action.canceled)]),
        0,
      );
    });
  });
}
