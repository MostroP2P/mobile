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

    test('accepts a port on a named host', () {
      expect(secure.normalize('wss://relay.example.com:8080'),
          'wss://relay.example.com:8080');
      expect(secure.normalize('relay.example.com:8080'),
          'wss://relay.example.com:8080');
      expect(secure.normalize('wss://relay.example.com:0'), isNull);
      expect(secure.normalize('wss://relay.example.com:65536'), isNull);
    });

    test('rejects ws:// URLs', () {
      expect(secure.normalize('ws://relay.example.com'), isNull);
    });

    test('rejects ws://localhost with port', () {
      expect(secure.normalize('ws://localhost:7000'), isNull);
    });

    test('rejects local hosts even over wss://', () {
      expect(secure.normalize('wss://localhost:7000'), isNull);
      expect(secure.normalize('wss://10.0.2.2:7000'), isNull);
    });

    test('rejects IP addresses', () {
      expect(secure.normalize('wss://127.0.0.1'), isNull);
      expect(secure.normalize('127.0.0.1:7000'), isNull);
    });

    test('rejects http(s) URLs', () {
      expect(secure.normalize('https://relay.example.com'), isNull);
      expect(secure.normalize('http://relay.example.com'), isNull);
    });

    test('accepts bare domains that merely start with "http"', () {
      expect(secure.normalize('httprelay.example.com'),
          'wss://httprelay.example.com');
    });

    test('rejects unknown schemes', () {
      expect(secure.normalize('ftp://relay.example.com'), isNull);
    });

    test('strips trailing slashes', () {
      expect(secure.normalize('wss://relay.example.com/'),
          'wss://relay.example.com');
      expect(
          secure.normalize('relay.example.com//'), 'wss://relay.example.com');
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

    test('rejects ws:// on public domains (plain text only to local hosts)',
        () {
      expect(insecure.normalize('ws://relay.example.com'), isNull);
      expect(insecure.normalize('ws://host.docker.internal:7000'), isNull);
    });

    test('accepts wss:// on local hosts', () {
      expect(
          insecure.normalize('wss://localhost:7000'), 'wss://localhost:7000');
      expect(insecure.normalize('wss://10.0.2.2:7000'), 'wss://10.0.2.2:7000');
    });

    test('accepts a port on a named host', () {
      expect(insecure.normalize('wss://mostro-relay.local:7000'),
          'wss://mostro-relay.local:7000');
    });

    test('trims and lowercases input', () {
      expect(
          insecure.normalize('  WS://LocalHost:7000 '), 'ws://localhost:7000');
    });

    test('still rejects http(s) URLs', () {
      expect(insecure.normalize('http://localhost:7000'), isNull);
    });

    test('still rejects malformed hosts', () {
      expect(insecure.normalize('ws://local host'), isNull);
      expect(insecure.normalize('ws://localhost:abc'), isNull);
    });

    test('rejects IPv4 octets above 255', () {
      expect(insecure.normalize('ws://999.999.999.999:7000'), isNull);
      expect(insecure.normalize('ws://10.0.256.1'), isNull);
    });

    test('accepts ws:// on loopback and the RFC 1918 ranges', () {
      expect(insecure.normalize('ws://127.0.0.1'), 'ws://127.0.0.1');
      expect(insecure.normalize('ws://10.0.2.2:7000'), 'ws://10.0.2.2:7000');
      expect(insecure.normalize('ws://172.16.0.1:7000'),
          'ws://172.16.0.1:7000');
      expect(insecure.normalize('ws://172.31.255.255'), 'ws://172.31.255.255');
      expect(insecure.normalize('ws://192.168.1.50:7000'),
          'ws://192.168.1.50:7000');
    });

    test('rejects public IPv4 addresses: they are not local hosts', () {
      expect(insecure.normalize('ws://8.8.8.8'), isNull);
      expect(insecure.normalize('ws://203.0.113.10:7000'), isNull);
      // Not acceptable over TLS either: the domain-only policy still holds
      // for anything that is not a local host.
      expect(insecure.normalize('wss://8.8.8.8'), isNull);
      expect(insecure.normalize('wss://203.0.113.10:7000'), isNull);
    });

    test('rejects the addresses just outside 172.16.0.0/12', () {
      expect(insecure.normalize('ws://172.15.0.1'), isNull);
      expect(insecure.normalize('ws://172.32.0.1'), isNull);
    });

    test('rejects ports above 65535 or zero', () {
      expect(insecure.normalize('ws://localhost:99999'), isNull);
      expect(insecure.normalize('ws://127.0.0.1:65536'), isNull);
      expect(insecure.normalize('ws://localhost:0'), isNull);
      expect(
          insecure.normalize('ws://localhost:65535'), 'ws://localhost:65535');
    });

    test('bare localhost gets wss:// prefix (no implicit downgrade)', () {
      expect(insecure.normalize('localhost:7000'), 'wss://localhost:7000');
    });
  });

  group('RelayUrlValidator.validate rejection reasons', () {
    const secure = RelayUrlValidator(allowInsecure: false);
    const insecure = RelayUrlValidator(allowInsecure: true);

    RelayUrlRejection? reasonOf(RelayUrlValidator v, String input) =>
        v.validate(input).rejection;

    test('ws:// in secure mode is insecureScheme', () {
      expect(reasonOf(secure, 'ws://localhost:7000'),
          RelayUrlRejection.insecureScheme);
    });

    test('ws:// to a public host is insecureScheme even when allowed', () {
      expect(reasonOf(insecure, 'ws://relay.example.com'),
          RelayUrlRejection.insecureScheme);
    });

    test('ws:// to a public IPv4 is invalidHost, not insecureScheme', () {
      // An IP address is never a valid relay host, so blaming the scheme
      // would suggest that wss:// towards it would work.
      expect(reasonOf(insecure, 'ws://8.8.8.8'),
          RelayUrlRejection.invalidHost);
    });

    test('ws:// with a bad port/octet is invalidHost when allowed', () {
      // Plain text to localhost is allowed in this build, so blaming the
      // scheme would be misleading: the port/octet is what is wrong.
      expect(reasonOf(insecure, 'ws://localhost:99999'),
          RelayUrlRejection.invalidHost);
      expect(reasonOf(insecure, 'ws://localhost:0'),
          RelayUrlRejection.invalidHost);
      expect(
          reasonOf(insecure, 'ws://10.0.256.1'), RelayUrlRejection.invalidHost);
      expect(reasonOf(insecure, 'ws://1.2.3'), RelayUrlRejection.invalidHost);
    });

    test('ws:// with a bad port/octet is still insecureScheme when not allowed',
        () {
      expect(reasonOf(secure, 'ws://localhost:99999'),
          RelayUrlRejection.insecureScheme);
    });

    test('http(s) is httpScheme', () {
      expect(reasonOf(secure, 'https://relay.example.com'),
          RelayUrlRejection.httpScheme);
      expect(reasonOf(insecure, 'http://localhost:7000'),
          RelayUrlRejection.httpScheme);
    });

    test('bad hosts are invalidHost', () {
      expect(reasonOf(secure, 'relay'), RelayUrlRejection.invalidHost);
      expect(
          reasonOf(secure, 'wss://127.0.0.1'), RelayUrlRejection.invalidHost);
      expect(reasonOf(secure, 'wss://relay.example.com:70000'),
          RelayUrlRejection.invalidHost);
    });

    test('accepted results carry the URL and no rejection', () {
      final result = secure.validate('Relay.Example.com/');
      expect(result.isAccepted, isTrue);
      expect(result.url, 'wss://relay.example.com');
      expect(result.rejection, isNull);
    });
  });

  group('RelayUrlValidator.canonicalKey', () {
    test('trims, strips trailing slashes and lowercases scheme and host', () {
      expect(RelayUrlValidator.canonicalKey('  WSS://Relay.Example.com// '),
          'wss://relay.example.com');
      expect(RelayUrlValidator.canonicalKey('Relay.Example.com/'),
          'relay.example.com');
    });

    test('keeps the case of a path', () {
      expect(RelayUrlValidator.canonicalKey('WSS://Relay.Example.com/Nostr/'),
          'wss://relay.example.com/Nostr');
    });

    test('matches what normalize produces', () {
      const v = RelayUrlValidator(allowInsecure: false);
      const input = 'WSS://Relay.Example.com/';
      expect(RelayUrlValidator.canonicalKey(input), v.normalize(input));
    });
  });
}
