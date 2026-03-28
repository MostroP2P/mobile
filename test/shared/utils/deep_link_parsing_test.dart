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
          'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab';
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
}
