import 'package:mostro_mobile/data/models/bond_payout_request.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/payload.dart';
import 'package:test/test.dart';

void main() {
  group('BondPayoutRequest.fromJson', () {
    test('parses real wire payload from mostrod', () {
      // Real wire payload mostrod (mostro-core 0.11.3) ships with
      // Action.addBondInvoice. The nested order's status is intentionally
      // null (the field is not meaningful in the bond-payout request
      // context; Order.fromJson defaults to Status.pending).
      final json = {
        'order': {
          'id': '1d554f35-3121-47ef-8779-834d6d91a24d',
          'kind': 'buy',
          'status': null,
          'amount': 5,
          'fiat_code': 'CUP',
          'min_amount': null,
          'max_amount': null,
          'fiat_amount': 200,
          'payment_method': 'Saldo móvil',
          'premium': 0,
          'created_at': null,
          'expires_at': null,
        },
        'slashed_at': 1778867884,
      };

      final payload = BondPayoutRequest.fromJson(json);

      expect(payload.order.id, '1d554f35-3121-47ef-8779-834d6d91a24d');
      expect(payload.order.amount, 5);
      expect(payload.order.fiatCode, 'CUP');
      expect(payload.slashedAt, 1778867884);
    });

    test('Payload.fromJson dispatches bond_payout_request to BondPayoutRequest',
        () {
      // Top-level dispatch shape: { "bond_payout_request": { order, slashed_at } }
      final wirePayload = {
        'bond_payout_request': {
          'order': {
            'id': 'aaaa',
            'kind': 'sell',
            'status': null,
            'amount': 100,
            'fiat_code': 'USD',
            'fiat_amount': 50,
            'payment_method': 'cash',
            'premium': 0,
          },
          'slashed_at': 1700000000,
        },
      };

      final result = Payload.fromJson(wirePayload);

      expect(result, isA<BondPayoutRequest>());
      final bpr = result as BondPayoutRequest;
      expect(bpr.slashedAt, 1700000000);
      expect(bpr.order.amount, 100);
    });

    test('round-trip toJson / fromJson preserves data', () {
      // Order does not override == (identity equality only), so compare
      // field-by-field. The wire shape must survive the round-trip cleanly.
      final original = BondPayoutRequest(
        order: Order.fromJson({
          'id': 'bbbb',
          'kind': 'buy',
          'status': null,
          'amount': 42,
          'fiat_code': 'EUR',
          'fiat_amount': 10,
          'payment_method': 'sepa',
          'premium': 0,
        }),
        slashedAt: 1700000000,
      );

      final json = original.toJson();
      final round = BondPayoutRequest.fromJson(
          json['bond_payout_request'] as Map<String, dynamic>);

      expect(round.slashedAt, original.slashedAt);
      expect(round.order.id, original.order.id);
      expect(round.order.kind, original.order.kind);
      expect(round.order.amount, original.order.amount);
      expect(round.order.fiatCode, original.order.fiatCode);
      expect(round.order.fiatAmount, original.order.fiatAmount);
      expect(round.order.paymentMethod, original.order.paymentMethod);
    });
  });
}
