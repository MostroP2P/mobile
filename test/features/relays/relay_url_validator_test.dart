import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/features/relays/relay_url_validator.dart';

void main() {
  group('RelayUrlValidator.normalize (secure mode)', () {
    const secure = RelayUrlValidator(allowInsecure: false);

    test('keeps wss:// URLs as-is', () {
      expect(secure.normalize('wss://relay.example.com'),
          'wss://relay.example.com');
    });

    test('auto-adds wss:// prefix to bare domains', () {
      expect(secure.normalize('relay.example.com'), 'wss://relay.example.com');
    });

    test('rejects ws:// URLs', () {
      expect(secure.normalize('ws://relay.example.com'), isNull);
    });

    test('rejects ws://localhost with port', () {
      expect(secure.normalize('ws://localhost:7000'), isNull);
    });

    test('rejects IP addresses', () {
      expect(secure.normalize('wss://127.0.0.1'), isNull);
      expect(secure.normalize('127.0.0.1:7000'), isNull);
    });

    test('rejects http(s) URLs', () {
      expect(secure.normalize('https://relay.example.com'), isNull);
      expect(secure.normalize('http://relay.example.com'), isNull);
    });

    test('rejects domains without a dot', () {
      expect(secure.normalize('localhost'), isNull);
      expect(secure.normalize('relay'), isNull);
    });
  });

  group('RelayUrlValidator.normalize (insecure allowed)', () {
    const insecure = RelayUrlValidator(allowInsecure: true);

    test('accepts ws://localhost with port', () {
      expect(insecure.normalize('ws://localhost:7000'), 'ws://localhost:7000');
    });

    test('accepts ws://localhost without port', () {
      expect(insecure.normalize('ws://localhost'), 'ws://localhost');
    });

    test('accepts ws:// on IPv4 with port', () {
      expect(insecure.normalize('ws://10.0.2.2:7000'), 'ws://10.0.2.2:7000');
      expect(insecure.normalize('ws://127.0.0.1'), 'ws://127.0.0.1');
    });

    test('accepts ws:// on public domains', () {
      expect(insecure.normalize('ws://relay.example.com'),
          'ws://relay.example.com');
    });

    test('trims and lowercases input', () {
      expect(insecure.normalize('  WS://LocalHost:7000 '), 'ws://localhost:7000');
    });

    test('still rejects http(s) URLs', () {
      expect(insecure.normalize('http://localhost:7000'), isNull);
    });

    test('still rejects malformed hosts', () {
      expect(insecure.normalize('ws://local host'), isNull);
      expect(insecure.normalize('ws://localhost:abc'), isNull);
    });

    test('bare localhost gets wss:// prefix (no implicit downgrade)', () {
      expect(insecure.normalize('localhost:7000'), 'wss://localhost:7000');
    });
  });

  group('RelayUrlValidator.isValidHost', () {
    test('strips protocol prefixes before validating', () {
      const secure = RelayUrlValidator(allowInsecure: false);
      expect(secure.isValidHost('wss://relay.example.com'), isTrue);
      expect(secure.isValidHost('https://relay.example.com'), isTrue);
      expect(secure.isValidHost('ws://relay.example.com'), isTrue);
    });
  });
}
