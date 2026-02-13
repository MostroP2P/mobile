import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/services/nwc/nwc_connection.dart';
import 'package:mostro_mobile/services/nwc/nwc_exceptions.dart';

void main() {
  group('NwcConnection', () {
    const validPubkey =
        'b889ff5b1513b641e2a139f661a661364979c5beee91842f8f0ef42ab558e9d4';
    const validSecret =
        '71a8c14c1407c113601079c4302dab36460f0ccd0ad506f1f2dc73b5100e4f3c';
    const validRelay = 'wss://relay.damus.io';
    const validUri =
        'nostr+walletconnect://$validPubkey?relay=wss%3A%2F%2Frelay.damus.io&secret=$validSecret';

    test('parses valid URI', () {
      final conn = NwcConnection.fromUri(validUri);
      expect(conn.walletPubkey, validPubkey);
      expect(conn.relayUrls, [validRelay]);
      expect(conn.secret, validSecret);
      expect(conn.lud16, isNull);
    });

    test('parses URI with lud16', () {
      final uri = '$validUri&lud16=user%40example.com';
      final conn = NwcConnection.fromUri(uri);
      expect(conn.lud16, 'user@example.com');
    });

    test('parses URI with multiple relays', () {
      final uri =
          'nostr+walletconnect://$validPubkey?relay=wss%3A%2F%2Frelay.damus.io&relay=wss%3A%2F%2Frelay.snort.social&secret=$validSecret';
      final conn = NwcConnection.fromUri(uri);
      expect(conn.relayUrls, hasLength(2));
      expect(conn.relayUrls[0], 'wss://relay.damus.io');
      expect(conn.relayUrls[1], 'wss://relay.snort.social');
    });

    test('trims whitespace', () {
      final conn = NwcConnection.fromUri('  $validUri  ');
      expect(conn.walletPubkey, validPubkey);
    });

    test('throws on wrong scheme', () {
      expect(
        () => NwcConnection.fromUri(
            'https://$validPubkey?relay=$validRelay&secret=$validSecret'),
        throwsA(isA<NwcInvalidUriException>()),
      );
    });

    test('throws on missing pubkey', () {
      expect(
        () => NwcConnection.fromUri(
            'nostr+walletconnect://?relay=$validRelay&secret=$validSecret'),
        throwsA(isA<NwcInvalidUriException>()),
      );
    });

    test('throws on invalid pubkey (wrong length)', () {
      expect(
        () => NwcConnection.fromUri(
            'nostr+walletconnect://abcd?relay=wss%3A%2F%2Frelay.damus.io&secret=$validSecret'),
        throwsA(isA<NwcInvalidUriException>()),
      );
    });

    test('throws on missing relay', () {
      expect(
        () => NwcConnection.fromUri(
            'nostr+walletconnect://$validPubkey?secret=$validSecret'),
        throwsA(isA<NwcInvalidUriException>()),
      );
    });

    test('throws on invalid relay URL', () {
      expect(
        () => NwcConnection.fromUri(
            'nostr+walletconnect://$validPubkey?relay=http%3A%2F%2Fbad.relay&secret=$validSecret'),
        throwsA(isA<NwcInvalidUriException>()),
      );
    });

    test('throws on missing secret', () {
      expect(
        () => NwcConnection.fromUri(
            'nostr+walletconnect://$validPubkey?relay=wss%3A%2F%2Frelay.damus.io'),
        throwsA(isA<NwcInvalidUriException>()),
      );
    });

    test('throws on invalid secret (wrong length)', () {
      expect(
        () => NwcConnection.fromUri(
            'nostr+walletconnect://$validPubkey?relay=wss%3A%2F%2Frelay.damus.io&secret=abcd'),
        throwsA(isA<NwcInvalidUriException>()),
      );
    });

    test('roundtrips via toUri', () {
      final conn = NwcConnection.fromUri(validUri);
      final roundtripped = NwcConnection.fromUri(conn.toUri());
      expect(roundtripped, conn);
    });

    test('equality', () {
      final a = NwcConnection.fromUri(validUri);
      final b = NwcConnection.fromUri(validUri);
      expect(a, b);
    });
  });
}
