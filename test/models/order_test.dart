import 'dart:convert';
import 'dart:io';

import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:test/test.dart';

Future<Map<String, dynamic>> loadJson(String path) async {
  final file = File(path);
  final contents = await file.readAsString();
  return jsonDecode(contents);
}

void main() {
  group('Order Tests', () {
    test('Create new Order with default values', () {
      final order = Order(
        kind: OrderType.sell,
        fiatCode: 'VES',
        fiatAmount: 100,
        paymentMethod: 'face to face',
        premium: 1,
      );

      expect(order.status, equals(Status.pending));
      expect(order.amount, equals(0));
      expect(order.fiatAmount, equals(100));
    });

    test(
        'fromJson accepts a SmallOrder with null status (Phase 3.5 bond ack)',
        () {
      final smallOrder = {
        'id': '6fec64ea-f2d1-453b-ba1d-929c3cb62244',
        'kind': 'sell',
        'status': null,
        'amount': 250,
        'fiat_code': 'CUP',
        'min_amount': null,
        'max_amount': null,
        'fiat_amount': 222,
        'payment_method': 'hhhh',
        'premium': 0,
        'created_at': null,
        'expires_at': null,
      };

      final order = Order.fromJson(smallOrder);

      expect(order.status, equals(Status.pending));
      expect(order.amount, equals(250));
      expect(order.fiatCode, equals('CUP'));
      expect(order.kind, equals(OrderType.sell));
    });
  });

  group('Order Tests with JSON', () {
    test('Parse new sell order from JSON file', () async {
      // Load JSON data
      final jsonData = await loadJson('test/examples/new_sell_order.json');

      // Parse JSON to model
      final orderData = jsonData['order']['payload']['order'];
      final order = Order.fromJson(orderData);

      // Validate model properties
      expect(order.kind, equals(OrderType.sell));
      expect(order.status, equals(Status.pending));
      expect(order.amount, equals(0));
      expect(order.fiatCode, equals('VES'));
      expect(order.fiatAmount, equals(100));
      expect(order.paymentMethod, equals('face to face'));
      expect(order.premium, equals(1));
    });
  });

  group('Order value equality', () {
    Order build({
      String? id = 'order-1',
      Status status = Status.pending,
      int amount = 50000,
      int? minAmount,
      int? maxAmount,
      int fiatAmount = 100,
      String paymentMethod = 'Wire transfer',
      int premium = 0,
      String? masterBuyerPubkey,
      String? masterSellerPubkey,
      String? buyerTradePubkey,
      String? sellerTradePubkey,
      String? buyerInvoice,
      int? createdAt = 1700000000,
      int? expiresAt = 1700003600,
    }) =>
        Order(
          id: id,
          kind: OrderType.sell,
          status: status,
          amount: amount,
          fiatCode: 'USD',
          minAmount: minAmount,
          maxAmount: maxAmount,
          fiatAmount: fiatAmount,
          paymentMethod: paymentMethod,
          premium: premium,
          masterBuyerPubkey: masterBuyerPubkey,
          masterSellerPubkey: masterSellerPubkey,
          buyerTradePubkey: buyerTradePubkey,
          sellerTradePubkey: sellerTradePubkey,
          buyerInvoice: buyerInvoice,
          createdAt: createdAt,
          expiresAt: expiresAt,
        );

    test('two distinct instances built from the same data are equal', () {
      expect(build(), equals(build()));
      expect(build().hashCode, equals(build().hashCode));
    });

    test('an instance equals itself', () {
      final order = build();

      expect(order, equals(order));
    });

    test('is not equal to a value of another type', () {
      expect(build(), isNot(equals('not an order')));
    });

    test('differing in any compared field breaks equality', () {
      expect(build(), isNot(equals(build(id: 'order-2'))));
      expect(build(), isNot(equals(build(status: Status.active))));
      expect(build(), isNot(equals(build(amount: 60000))));
      expect(build(), isNot(equals(build(minAmount: 10))));
      expect(build(), isNot(equals(build(maxAmount: 20))));
      expect(build(), isNot(equals(build(fiatAmount: 200))));
      expect(build(), isNot(equals(build(paymentMethod: 'Cash'))));
      expect(build(), isNot(equals(build(premium: 5))));
      expect(build(), isNot(equals(build(masterBuyerPubkey: 'mb'))));
      expect(build(), isNot(equals(build(masterSellerPubkey: 'ms'))));
      expect(build(), isNot(equals(build(buyerTradePubkey: 'bt'))));
      expect(build(), isNot(equals(build(sellerTradePubkey: 'st'))));
      expect(build(), isNot(equals(build(buyerInvoice: 'lnbc1'))));
      expect(build(), isNot(equals(build(createdAt: 1))));
      expect(build(), isNot(equals(build(expiresAt: 2))));
    });

    test('differing in kind breaks equality', () {
      final sell = build();
      final buy = Order(
        id: sell.id,
        kind: OrderType.buy,
        status: sell.status,
        amount: sell.amount,
        fiatCode: sell.fiatCode,
        fiatAmount: sell.fiatAmount,
        paymentMethod: sell.paymentMethod,
        premium: sell.premium,
        createdAt: sell.createdAt,
        expiresAt: sell.expiresAt,
      );

      expect(sell, isNot(equals(buy)));
    });

    test('differing in fiatCode breaks equality', () {
      final usd = build();
      final ves = Order(
        id: usd.id,
        kind: usd.kind,
        status: usd.status,
        amount: usd.amount,
        fiatCode: 'VES',
        fiatAmount: usd.fiatAmount,
        paymentMethod: usd.paymentMethod,
        premium: usd.premium,
        createdAt: usd.createdAt,
        expiresAt: usd.expiresAt,
      );

      expect(usd, isNot(equals(ves)));
    });

    test('copyWith result equals an order built with the same values', () {
      final updated = build().copyWith(
        status: Status.active,
        buyerInvoice: 'lnbc1',
      );

      expect(
        updated,
        equals(build(status: Status.active, buyerInvoice: 'lnbc1')),
      );
    });

    test('equal orders collapse in a set', () {
      expect({build(), build()}, hasLength(1));
    });
  });
}
