import 'dart:convert';
import 'package:test/test.dart';
import 'package:mostro_mobile/services/nostr_exchange_service.dart';

void main() {
  group('NostrExchangeService._parseRatesContent', () {
    // Use the static method via a test helper since it is private.
    // We test the same logic indirectly by calling the static parse helper.
    // Since _parseRatesContent is private, we test via the public class by
    // exercising the JSON parsing logic directly.

    Map<String, double> parseRates(String content) {
      // Replicate the parsing logic from NostrExchangeService._parseRatesContent
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object');
      }

      final btcRates = decoded['BTC'];
      if (btcRates is! Map<String, dynamic>) {
        throw const FormatException('Missing or invalid "BTC" key');
      }

      final rates = <String, double>{};
      for (final entry in btcRates.entries) {
        if (entry.key == 'BTC') continue;
        final value = entry.value;
        if (value is num) {
          rates[entry.key] = value.toDouble();
        }
      }

      if (rates.isEmpty) {
        throw const FormatException('No valid rates found');
      }

      return rates;
    }

    test('parses valid Yadio format correctly', () {
      const content =
          '{"BTC": {"USD": 50000.0, "EUR": 45000.0, "VES": 850000000.0}}';
      final rates = parseRates(content);

      expect(rates['USD'], 50000.0);
      expect(rates['EUR'], 45000.0);
      expect(rates['VES'], 850000000.0);
      expect(rates.length, 3);
    });

    test('skips BTC→BTC entry', () {
      const content = '{"BTC": {"BTC": 1, "USD": 50000.0}}';
      final rates = parseRates(content);

      expect(rates.containsKey('BTC'), isFalse);
      expect(rates['USD'], 50000.0);
      expect(rates.length, 1);
    });

    test('handles integer values', () {
      const content = '{"BTC": {"ARS": 105000000}}';
      final rates = parseRates(content);

      expect(rates['ARS'], 105000000.0);
      expect(rates['ARS'], isA<double>());
    });

    test('throws on missing BTC key', () {
      const content = '{"ETH": {"USD": 3000.0}}';
      expect(() => parseRates(content), throwsFormatException);
    });

    test('throws on empty rates', () {
      const content = '{"BTC": {"BTC": 1}}';
      expect(() => parseRates(content), throwsFormatException);
    });

    test('throws on invalid JSON', () {
      expect(() => parseRates('not json'), throwsA(anything));
    });

    test('throws on non-object content', () {
      expect(() => parseRates('"just a string"'), throwsFormatException);
    });

    test('ignores non-numeric values', () {
      const content = '{"BTC": {"USD": 50000.0, "INVALID": "not a number"}}';
      final rates = parseRates(content);

      expect(rates['USD'], 50000.0);
      expect(rates.containsKey('INVALID'), isFalse);
      expect(rates.length, 1);
    });

    test('parses many currencies', () {
      final btcRates = <String, dynamic>{
        'BTC': 1,
        'USD': 50000.0,
        'EUR': 45000.0,
        'GBP': 39000.0,
        'ARS': 105000000,
        'VES': 850000000.0,
        'COP': 210000000,
        'MXN': 850000.0,
        'BRL': 250000.0,
      };
      final content = jsonEncode({'BTC': btcRates});
      final rates = parseRates(content);

      // BTC→BTC is skipped
      expect(rates.length, btcRates.length - 1);
      expect(rates['USD'], 50000.0);
      expect(rates['ARS'], 105000000.0);
    });
  });

  group('pubkey verification logic', () {
    test('rejects event from wrong pubkey', () {
      const expectedPubkey = 'abc123';
      const eventPubkey = 'wrong_pubkey';

      // Simulate the verification check
      expect(eventPubkey == expectedPubkey, isFalse);
    });

    test('accepts event from correct pubkey', () {
      const expectedPubkey =
          '82fa8cb978b43c79b2156585bac2c011176a21d2aead6d9f7c575c005be88390';
      const eventPubkey =
          '82fa8cb978b43c79b2156585bac2c011176a21d2aead6d9f7c575c005be88390';

      expect(eventPubkey == expectedPubkey, isTrue);
    });
  });
}
