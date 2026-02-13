import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/services/nwc/nwc_exceptions.dart';
import 'package:mostro_mobile/services/nwc/nwc_models.dart';

void main() {
  group('NwcRequest', () {
    test('serializes to JSON', () {
      const request = NwcRequest(
        method: 'pay_invoice',
        params: {'invoice': 'lnbc50n1...'},
      );
      final json = jsonDecode(request.toJson()) as Map<String, dynamic>;
      expect(json['method'], 'pay_invoice');
      expect(json['params']['invoice'], 'lnbc50n1...');
    });

    test('deserializes from JSON', () {
      final json = jsonEncode({
        'method': 'get_balance',
        'params': {},
      });
      final request = NwcRequest.fromJson(json);
      expect(request.method, 'get_balance');
      expect(request.params, isEmpty);
    });

    test('handles missing params as empty map', () {
      final json = jsonEncode({'method': 'get_info'});
      final request = NwcRequest.fromJson(json);
      expect(request.params, isEmpty);
    });
  });

  group('NwcResponse', () {
    test('parses successful response', () {
      final json = jsonEncode({
        'result_type': 'pay_invoice',
        'error': null,
        'result': {'preimage': 'abc123', 'fees_paid': 100},
      });
      final response = NwcResponse.fromJson(json);
      expect(response.isSuccess, isTrue);
      expect(response.resultType, 'pay_invoice');
      expect(response.result!['preimage'], 'abc123');
    });

    test('parses error response', () {
      final json = jsonEncode({
        'result_type': 'pay_invoice',
        'error': {
          'code': 'PAYMENT_FAILED',
          'message': 'Route not found',
        },
        'result': null,
      });
      final response = NwcResponse.fromJson(json);
      expect(response.isSuccess, isFalse);
      expect(response.error!.code, NwcErrorCode.paymentFailed);
      expect(response.error!.message, 'Route not found');
    });

    test('roundtrips via toJson', () {
      const original = NwcResponse(
        resultType: 'get_balance',
        result: {'balance': 50000},
      );
      final roundtripped = NwcResponse.fromJson(original.toJson());
      expect(roundtripped.resultType, original.resultType);
      expect(roundtripped.result, original.result);
    });
  });

  group('NwcError', () {
    test('parses all known error codes', () {
      for (final code in NwcErrorCode.values) {
        final error = NwcError.fromMap({
          'code': code.value,
          'message': 'test',
        });
        expect(error.code, code);
      }
    });

    test('unknown code falls back to other', () {
      final error = NwcError.fromMap({
        'code': 'UNKNOWN_CODE',
        'message': 'test',
      });
      expect(error.code, NwcErrorCode.other);
    });
  });

  group('PayInvoiceParams', () {
    test('toMap with required fields only', () {
      const params = PayInvoiceParams(invoice: 'lnbc50n1...');
      final map = params.toMap();
      expect(map['invoice'], 'lnbc50n1...');
      expect(map.containsKey('amount'), isFalse);
      expect(map.containsKey('metadata'), isFalse);
    });

    test('toMap with optional fields', () {
      const params = PayInvoiceParams(
        invoice: 'lnbc50n1...',
        amount: 1000,
        metadata: {'comment': 'test'},
      );
      final map = params.toMap();
      expect(map['amount'], 1000);
      expect(map['metadata']['comment'], 'test');
    });
  });

  group('PayInvoiceResult', () {
    test('parses from map', () {
      final result = PayInvoiceResult.fromMap({
        'preimage': 'abc123',
        'fees_paid': 50,
      });
      expect(result.preimage, 'abc123');
      expect(result.feesPaid, 50);
    });

    test('handles missing optional fees_paid', () {
      final result = PayInvoiceResult.fromMap({'preimage': 'abc123'});
      expect(result.feesPaid, isNull);
    });
  });

  group('MakeInvoiceParams', () {
    test('toMap with required fields', () {
      const params = MakeInvoiceParams(amount: 5000);
      final map = params.toMap();
      expect(map['amount'], 5000);
      expect(map.containsKey('description'), isFalse);
    });

    test('toMap with all fields', () {
      const params = MakeInvoiceParams(
        amount: 5000,
        description: 'Test invoice',
        expiry: 3600,
      );
      final map = params.toMap();
      expect(map['description'], 'Test invoice');
      expect(map['expiry'], 3600);
    });
  });

  group('TransactionResult', () {
    test('parses full transaction', () {
      final result = TransactionResult.fromMap({
        'type': 'incoming',
        'state': 'settled',
        'invoice': 'lnbc50n1...',
        'description': 'Test',
        'preimage': 'abc123',
        'payment_hash': 'def456',
        'amount': 5000,
        'fees_paid': 10,
        'created_at': 1700000000,
        'expires_at': 1700003600,
        'settled_at': 1700001000,
      });
      expect(result.type, 'incoming');
      expect(result.state, 'settled');
      expect(result.amount, 5000);
      expect(result.settledAt, 1700001000);
    });

    test('handles minimal fields', () {
      final result = TransactionResult.fromMap({
        'type': 'outgoing',
        'amount': 1000,
        'created_at': 1700000000,
      });
      expect(result.type, 'outgoing');
      expect(result.state, isNull);
      expect(result.invoice, isNull);
    });
  });

  group('GetBalanceResult', () {
    test('parses balance', () {
      final result = GetBalanceResult.fromMap({'balance': 100000});
      expect(result.balance, 100000);
    });
  });

  group('GetInfoResult', () {
    test('parses full info', () {
      final result = GetInfoResult.fromMap({
        'alias': 'MyWallet',
        'color': '#ff0000',
        'pubkey': 'abc123',
        'network': 'mainnet',
        'block_height': 800000,
        'block_hash': 'hash123',
        'methods': ['pay_invoice', 'get_balance'],
        'notifications': ['payment_received'],
      });
      expect(result.alias, 'MyWallet');
      expect(result.network, 'mainnet');
      expect(result.methods, hasLength(2));
      expect(result.notifications, ['payment_received']);
    });

    test('handles missing optional fields', () {
      final result = GetInfoResult.fromMap({
        'methods': ['pay_invoice'],
      });
      expect(result.alias, isNull);
      expect(result.methods, ['pay_invoice']);
      expect(result.notifications, isNull);
    });
  });

  group('LookupInvoiceParams', () {
    test('toMap with payment_hash', () {
      const params = LookupInvoiceParams(paymentHash: 'abc123');
      final map = params.toMap();
      expect(map['payment_hash'], 'abc123');
      expect(map.containsKey('invoice'), isFalse);
    });

    test('toMap with invoice', () {
      const params = LookupInvoiceParams(invoice: 'lnbc50n1...');
      final map = params.toMap();
      expect(map['invoice'], 'lnbc50n1...');
    });
  });
}
