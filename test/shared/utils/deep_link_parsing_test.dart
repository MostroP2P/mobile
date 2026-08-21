import 'package:test/test.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

void main() {
  group('NostrUtils.parseMostroUrl — mostro pubkey extraction', () {
    test('parses URL without mostro param (backward compatible)', () {
      const url =
          'mostro:e215c07e-b1f9-45b0-9640-0295067ee99a?relays=wss://relay.mostro.network';
      final result = NostrUtils.parseMostroUrl(url);

      expect(result, isNotNull);
      expect(result!['orderId'], 'e215c07e-b1f9-45b0-9640-0295067ee99a');
      expect(result['relays'], ['wss://relay.mostro.network']);
      expect(result['mostroPubkey'], isNull);
    });

    test('parses URL with mostro pubkey param', () {
      const pubkey =
          '82fa8cb978b43c79b2156585bac2c011176a21d2aead6d9f7c575c005be88390';
      final url =
          'mostro:e215c07e-b1f9-45b0-9640-0295067ee99a?relays=wss://relay.mostro.network&mostro=$pubkey';
      final result = NostrUtils.parseMostroUrl(url);

      expect(result, isNotNull);
      expect(result!['orderId'], 'e215c07e-b1f9-45b0-9640-0295067ee99a');
      expect(result['relays'], ['wss://relay.mostro.network']);
      expect(result['mostroPubkey'], pubkey);
    });

    test('parses URL with multiple relays and mostro pubkey', () {
      const pubkey =
          'abcdef1234567890abcdef1234567890abcdef1234567890abcdef12345678ab';
      final url =
          'mostro:order-id-123?relays=wss://relay1.example.com,wss://relay2.example.com&mostro=$pubkey';
      final result = NostrUtils.parseMostroUrl(url);

      expect(result, isNotNull);
      expect(result!['relays'], hasLength(2));
      expect(result['mostroPubkey'], pubkey);
    });

    test('ignores empty mostro param', () {
      const url =
          'mostro:e215c07e-b1f9-45b0-9640-0295067ee99a?relays=wss://relay.mostro.network&mostro=';
      final result = NostrUtils.parseMostroUrl(url);

      expect(result, isNotNull);
      expect(result!['mostroPubkey'], isNull);
    });

    test('rejects malformed pubkey (too short)', () {
      const url =
          'mostro:e215c07e-b1f9-45b0-9640-0295067ee99a?relays=wss://relay.mostro.network&mostro=abc123';
      final result = NostrUtils.parseMostroUrl(url);

      expect(result, isNotNull);
      expect(result!['mostroPubkey'], isNull);
    });

    test('rejects pubkey with non-hex characters', () {
      const url =
          'mostro:e215c07e-b1f9-45b0-9640-0295067ee99a?relays=wss://relay.mostro.network&mostro=zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz';
      final result = NostrUtils.parseMostroUrl(url);

      expect(result, isNotNull);
      expect(result!['mostroPubkey'], isNull);
    });

    test('normalizes uppercase pubkey to lowercase', () {
      const url =
          'mostro:e215c07e-b1f9-45b0-9640-0295067ee99a?relays=wss://relay.mostro.network&mostro=82FA8CB978B43C79B2156585BAC2C011176A21D2AEAD6D9F7C575C005BE88390';
      final result = NostrUtils.parseMostroUrl(url);

      expect(result, isNotNull);
      expect(
        result!['mostroPubkey'],
        '82fa8cb978b43c79b2156585bac2c011176a21d2aead6d9f7c575c005be88390',
      );
    });

    test('isValidMostroUrl accepts URL with mostro param', () {
      const url =
          'mostro:e215c07e?relays=wss://relay.mostro.network&mostro=abc123';
      expect(NostrUtils.isValidMostroUrl(url), isTrue);
    });

    test('isValidMostroUrl still rejects URL without relays', () {
      const url = 'mostro:e215c07e?mostro=abc123';
      expect(NostrUtils.isValidMostroUrl(url), isFalse);
    });
  });

  group('Mostro instance comparison via parseMostroUrl', () {
    const currentPubkey =
        '82fa8cb978b43c79b2156585bac2c011176a21d2aead6d9f7c575c005be88390';

    test('same pubkey in link matches current instance', () {
      final url =
          'mostro:order-123?relays=wss://relay.mostro.network&mostro=$currentPubkey';
      final result = NostrUtils.parseMostroUrl(url);

      expect(result, isNotNull);
      expect(result!['mostroPubkey'] == currentPubkey, isTrue);
    });

    test('different pubkey in link does not match current instance', () {
      const otherPubkey =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final url =
          'mostro:order-123?relays=wss://relay.mostro.network&mostro=$otherPubkey';
      final result = NostrUtils.parseMostroUrl(url);

      expect(result, isNotNull);
      expect(result!['mostroPubkey'] == currentPubkey, isFalse);
      expect(result['mostroPubkey'], otherPubkey);
    });

    test('mixed-case pubkey is normalized and matches lowercase', () {
      final url =
          'mostro:order-123?relays=wss://relay.mostro.network&mostro=82FA8CB978B43C79B2156585BAC2C011176A21D2AEAD6D9F7C575C005BE88390';
      final result = NostrUtils.parseMostroUrl(url);

      expect(result, isNotNull);
      expect(result!['mostroPubkey'] == currentPubkey, isTrue);
    });

    test('absent mostro param means same instance (backward compatible)', () {
      const url = 'mostro:order-123?relays=wss://relay.mostro.network';
      final result = NostrUtils.parseMostroUrl(url);

      expect(result, isNotNull);
      // null mostroPubkey → app treats as same instance (no switch dialog)
      expect(result!['mostroPubkey'], isNull);
    });

    test('malformed pubkey is silently dropped (treated as same instance)', () {
      const url =
          'mostro:order-123?relays=wss://relay.mostro.network&mostro=not-a-valid-key';
      final result = NostrUtils.parseMostroUrl(url);

      expect(result, isNotNull);
      expect(result!['mostroPubkey'], isNull);
    });
  });

  group('NostrUtils.buildMostroUrl', () {
    const orderId = 'e215c07e-b1f9-45b0-9640-0295067ee99a';
    const pubkey =
        '82fa8cb978b43c79b2156585bac2c011176a21d2aead6d9f7c575c005be88390';

    test('builds a link its own parser reads back unchanged', () {
      final url = NostrUtils.buildMostroUrl(
        orderId: orderId,
        relays: const ['wss://relay.mostro.network', 'wss://relay.damus.io'],
        mostroPubkey: pubkey,
      );

      expect(url, isNotNull);
      expect(NostrUtils.isValidMostroUrl(url!), isTrue);

      final parsed = NostrUtils.parseMostroUrl(url);
      expect(parsed, isNotNull);
      expect(parsed!['orderId'], orderId);
      expect(parsed['relays'],
          ['wss://relay.mostro.network', 'wss://relay.damus.io']);
      expect(parsed['mostroPubkey'], pubkey);
    });

    test('omits the mostro param when no pubkey is given', () {
      final url = NostrUtils.buildMostroUrl(
        orderId: orderId,
        relays: const ['wss://relay.mostro.network'],
      );

      expect(url, isNot(contains('mostro=')));
      expect(NostrUtils.parseMostroUrl(url!)!['mostroPubkey'], isNull);
    });

    test('drops a pubkey the parser would reject rather than emitting it', () {
      final url = NostrUtils.buildMostroUrl(
        orderId: orderId,
        relays: const ['wss://relay.mostro.network'],
        mostroPubkey: 'not-a-pubkey',
      );

      expect(url, isNot(contains('mostro=')));
    });

    test('accepts a pubkey in upper case or 0x-prefixed', () {
      final url = NostrUtils.buildMostroUrl(
        orderId: orderId,
        relays: const ['wss://relay.mostro.network'],
        mostroPubkey: '0x${pubkey.toUpperCase()}',
      );

      expect(NostrUtils.parseMostroUrl(url!)!['mostroPubkey'], pubkey);
    });

    test('keeps only relays carrying a WebSocket scheme', () {
      final url = NostrUtils.buildMostroUrl(
        orderId: orderId,
        relays: const [
          'https://relay.example.com',
          '  wss://relay.mostro.network  ',
          'relay.example.org',
          'ws://localhost:7000',
        ],
      );

      expect(NostrUtils.parseMostroUrl(url!)!['relays'],
          ['wss://relay.mostro.network', 'ws://localhost:7000']);
    });

    test('removes duplicates and caps the relay count', () {
      final url = NostrUtils.buildMostroUrl(
        orderId: orderId,
        relays: const [
          'wss://a.example',
          'wss://a.example',
          'wss://b.example',
          'wss://c.example',
          'wss://d.example',
        ],
        maxRelays: 3,
      );

      expect(NostrUtils.parseMostroUrl(url!)!['relays'],
          ['wss://a.example', 'wss://b.example', 'wss://c.example']);
    });

    test('returns null when no usable relay is left', () {
      expect(
        NostrUtils.buildMostroUrl(
          orderId: orderId,
          relays: const ['https://relay.example.com'],
        ),
        isNull,
      );
      expect(
        NostrUtils.buildMostroUrl(orderId: orderId, relays: const []),
        isNull,
      );
    });

    test('returns null without an order id', () {
      expect(
        NostrUtils.buildMostroUrl(
          orderId: '   ',
          relays: const ['wss://relay.mostro.network'],
        ),
        isNull,
      );
    });
  });
}
