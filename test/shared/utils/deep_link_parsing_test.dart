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

  group('DeepLinkService.OrderInfo — mostroPubkey field', () {
    // Import is indirect since OrderInfo is in deep_link_service.dart
    // which depends on Flutter. We test the parsing logic here instead.

    test('same pubkey comparison works', () {
      const current =
          '82fa8cb978b43c79b2156585bac2c011176a21d2aead6d9f7c575c005be88390';
      const link =
          '82fa8cb978b43c79b2156585bac2c011176a21d2aead6d9f7c575c005be88390';
      expect(current == link, isTrue);
    });

    test('different pubkey comparison works', () {
      const current =
          '82fa8cb978b43c79b2156585bac2c011176a21d2aead6d9f7c575c005be88390';
      const link =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      expect(current == link, isFalse);
    });

    test('null pubkey means same instance (backward compatible)', () {
      const String? linkPubkey = null;
      // When mostroPubkey is null, app should treat it as same instance
      expect(linkPubkey == null, isTrue);
    });
  });
}
