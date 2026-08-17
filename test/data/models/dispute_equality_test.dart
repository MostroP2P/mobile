import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/order.dart';

void main() {
  Order order({Status status = Status.dispute}) => Order(
        id: 'order-1',
        kind: OrderType.sell,
        status: status,
        amount: 50000,
        fiatCode: 'USD',
        fiatAmount: 100,
        paymentMethod: 'Wire transfer',
        createdAt: 1700000000,
        expiresAt: 1700003600,
      );

  Dispute dispute({Order? attached}) => Dispute(
        disputeId: 'dispute-1',
        orderId: 'order-1',
        status: 'initiated',
        order: attached,
        adminPubkey: 'admin-pubkey',
        adminTookAt: DateTime.utc(2026, 1, 1),
        createdAt: DateTime.utc(2025, 12, 31),
        action: 'dispute-initiated-by-you',
      );

  group('Dispute value equality with an attached order', () {
    test('disputes holding equal-but-distinct orders are equal', () {
      expect(dispute(attached: order()), equals(dispute(attached: order())));
      expect(
        dispute(attached: order()).hashCode,
        equals(dispute(attached: order()).hashCode),
      );
    });

    test('disputes holding different orders are not equal', () {
      expect(
        dispute(attached: order()),
        isNot(equals(
          dispute(attached: order(status: Status.settledHoldInvoice)),
        )),
      );
    });

    test('an attached order is not equal to no order at all', () {
      expect(dispute(attached: order()), isNot(equals(dispute())));
    });
  });
}
