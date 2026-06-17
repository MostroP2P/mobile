import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/shared/utils/bond_slash_helpers.dart';

MostroMessage _msg(Action action) =>
    MostroMessage(action: action, id: 'order-1');

void main() {
  group('bondSlashCause', () {
    test('timeout when no dispute or admin action is present', () {
      expect(
        bondSlashCause([
          _msg(Action.payBondInvoice),
          _msg(Action.waitingBuyerInvoice),
          _msg(Action.canceled),
          _msg(Action.bondSlashed),
        ]),
        BondSlashCause.timeout,
      );
    });

    test('dispute when admin-settled is present', () {
      expect(
        bondSlashCause([
          _msg(Action.payBondInvoice),
          _msg(Action.disputeInitiatedByYou),
          _msg(Action.adminSettled),
          _msg(Action.bondSlashed),
        ]),
        BondSlashCause.dispute,
      );
    });

    test('dispute when admin-canceled is present', () {
      expect(
        bondSlashCause([
          _msg(Action.adminCanceled),
          _msg(Action.bondSlashed),
        ]),
        BondSlashCause.dispute,
      );
    });

    test('dispute when only a dispute-initiated action is present', () {
      expect(
        bondSlashCause([
          _msg(Action.disputeInitiatedByPeer),
          _msg(Action.bondSlashed),
        ]),
        BondSlashCause.dispute,
      );
      expect(
        bondSlashCause([
          _msg(Action.disputeInitiatedByYou),
          _msg(Action.bondSlashed),
        ]),
        BondSlashCause.dispute,
      );
    });

    test('timeout for an empty history (defensive default)', () {
      expect(bondSlashCause([]), BondSlashCause.timeout);
    });
  });

  group('orderBondWasSlashed', () {
    test('true when a bond-slashed message exists', () {
      expect(
        orderBondWasSlashed([
          _msg(Action.payBondInvoice),
          _msg(Action.bondSlashed),
        ]),
        isTrue,
      );
    });

    test('false when no bond-slashed message exists', () {
      expect(
        orderBondWasSlashed([
          _msg(Action.payBondInvoice),
          _msg(Action.canceled),
        ]),
        isFalse,
      );
    });

    test('false for an empty history', () {
      expect(orderBondWasSlashed([]), isFalse);
    });
  });
}
