import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/bond_payout_request.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/payment_request.dart';
import 'package:mostro_mobile/shared/utils/bond_payout_helpers.dart';

const _claimWindowDays = 15;

BondPayoutRequest _request({int slashedAt = 1700000000}) {
  return BondPayoutRequest(
    order: const BondPayoutOrder(
      id: 'order-1',
      kind: OrderType.buy,
      amount: 0,
      fiatCode: 'USD',
      fiatAmount: 100,
      paymentMethod: 'wire',
    ),
    slashedAt: slashedAt,
  );
}

MostroMessage<BondPayoutRequest> _addBondInvoiceMsg({
  required int timestamp,
  int slashedAt = 1700000000,
}) {
  return MostroMessage<BondPayoutRequest>(
    action: Action.addBondInvoice,
    id: 'order-1',
    payload: _request(slashedAt: slashedAt),
    timestamp: timestamp,
  );
}

MostroMessage<PaymentRequest> _paymentReplyMsg({required int timestamp}) {
  return MostroMessage<PaymentRequest>(
    action: Action.addBondInvoice,
    id: 'order-1',
    payload: PaymentRequest(lnInvoice: 'lnbc1...'),
    timestamp: timestamp,
  );
}

void main() {
  group('latestBondPayoutRequest', () {
    test('returns null on empty message list', () {
      expect(latestBondPayoutRequest([]), isNull);
    });

    test('returns null when latest add-bond-invoice is a PaymentRequest reply',
        () {
      final messages = [
        _addBondInvoiceMsg(timestamp: 100),
        _paymentReplyMsg(timestamp: 200),
      ];
      expect(latestBondPayoutRequest(messages), isNull);
    });

    test('picks the most recent BondPayoutRequest regardless of input order',
        () {
      final older = _addBondInvoiceMsg(timestamp: 100, slashedAt: 1);
      final newer = _addBondInvoiceMsg(timestamp: 500, slashedAt: 2);
      final result = latestBondPayoutRequest([newer, older]);
      expect(result, isNotNull);
      expect(result!.slashedAt, 2);

      final resultReversed = latestBondPayoutRequest([older, newer]);
      expect(resultReversed!.slashedAt, 2);
    });

    test('ignores messages whose action is not addBondInvoice', () {
      final unrelated = MostroMessage(
        action: Action.fiatSent,
        id: 'order-1',
        timestamp: 999,
      );
      final claim = _addBondInvoiceMsg(timestamp: 100);
      final result = latestBondPayoutRequest([unrelated, claim]);
      expect(result, isNotNull);
      expect(result!.slashedAt, 1700000000);
    });

    test('treats null timestamps as zero without throwing', () {
      final nullTs = MostroMessage<BondPayoutRequest>(
        action: Action.addBondInvoice,
        id: 'order-1',
        payload: _request(slashedAt: 7),
      );
      final newer = _addBondInvoiceMsg(timestamp: 10, slashedAt: 8);
      final result = latestBondPayoutRequest([nullTs, newer]);
      expect(result!.slashedAt, 8);
    });
  });

  group('hasPendingBondClaim', () {
    test('false when no add-bond-invoice is present', () {
      expect(hasPendingBondClaim([], _claimWindowDays), isFalse);
    });

    test('false once the claim window has expired', () {
      final slashedAtSecs =
          DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch ~/
              1000;
      final messages = [
        _addBondInvoiceMsg(timestamp: 100, slashedAt: slashedAtSecs),
      ];
      expect(hasPendingBondClaim(messages, _claimWindowDays), isFalse);
    });

    test('true while a BondPayoutRequest is within the claim window', () {
      final slashedAtSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final messages = [
        _addBondInvoiceMsg(timestamp: 100, slashedAt: slashedAtSecs),
      ];
      expect(hasPendingBondClaim(messages, _claimWindowDays), isTrue);
    });

    test('false after the user replied with a PaymentRequest', () {
      final slashedAtSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final messages = [
        _addBondInvoiceMsg(timestamp: 100, slashedAt: slashedAtSecs),
        _paymentReplyMsg(timestamp: 200),
      ];
      expect(hasPendingBondClaim(messages, _claimWindowDays), isFalse);
    });
  });
}
