import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/shared/utils/bond_slash_helpers.dart';

MostroMessage _msg(Action action) =>
    MostroMessage(action: action, id: 'order-1');

MostroMessage<Order> _bondSlashedMsg(int amount) => MostroMessage<Order>(
      action: Action.bondSlashed,
      id: 'order-1',
      payload: Order(
        kind: OrderType.sell,
        amount: amount,
        fiatCode: 'CUP',
        fiatAmount: 200,
        paymentMethod: 'ggg',
      ),
    );

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

  group('bondSlashIsTimeout', () {
    test('true when a plain canceled message is present (timeout path)', () {
      expect(
        bondSlashIsTimeout([
          _msg(Action.payBondInvoice),
          _msg(Action.canceled),
          _bondSlashedMsg(300),
        ]),
        isTrue,
      );
    });

    test('false for a dispute resolution (admin-settled, no canceled)', () {
      expect(
        bondSlashIsTimeout([
          _msg(Action.disputeInitiatedByYou),
          _msg(Action.adminSettled),
          _bondSlashedMsg(300),
        ]),
        isFalse,
      );
    });

    test('false for an admin-canceled dispute (no plain canceled)', () {
      expect(
        bondSlashIsTimeout([
          _msg(Action.adminCanceled),
          _bondSlashedMsg(300),
        ]),
        isFalse,
      );
    });

    test('false (safe default) when neither marker is present yet', () {
      // Early-arrival race: bond-slashed before the preceding message lands.
      expect(bondSlashIsTimeout([_bondSlashedMsg(300)]), isFalse);
      expect(bondSlashIsTimeout([]), isFalse);
    });

    test('false when canceled and a dispute marker conflict (conflict-safe)', () {
      expect(
        bondSlashIsTimeout([
          _msg(Action.canceled),
          _msg(Action.adminSettled),
          _bondSlashedMsg(300),
        ]),
        isFalse,
      );
    });
  });

  group('slashedBondAmount', () {
    test('returns the amount from the bond-slashed payload', () {
      expect(
        slashedBondAmount([
          _msg(Action.payBondInvoice),
          _bondSlashedMsg(300),
        ]),
        300,
      );
    });

    test('returns null when there is no bond-slashed message', () {
      expect(
        slashedBondAmount([
          _msg(Action.payBondInvoice),
          _msg(Action.canceled),
        ]),
        isNull,
      );
    });

    test('returns null for an empty history', () {
      expect(slashedBondAmount([]), isNull);
    });
  });
}
