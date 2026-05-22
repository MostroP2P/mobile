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
}
