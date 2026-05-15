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

    test('Parse add-bond-invoice order with null status', () {
      // mostrod sends status, created_at, expires_at as null in this payload;
      // only fiat context and amount carry meaning here.
      final orderData = {
        'id': '1d554f35-3121-47ef-8779-834d6d91a24d',
        'kind': 'sell',
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
      };

      final order = Order.fromJson(orderData);

      expect(order.kind, equals(OrderType.sell));
      expect(order.status, equals(Status.pending)); // safe default
      expect(order.amount, equals(5));
      expect(order.fiatCode, equals('CUP'));
      expect(order.fiatAmount, equals(200));
      expect(order.paymentMethod, equals('Saldo móvil'));
    });
  });
}
