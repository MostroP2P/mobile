import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

void main() {
  group('NostrUtils nevent decoding tests', () {
    const testNevent = 'nevent1qqs9hcuev4z4frqnn5wagnupzg4dahcwkyy9r3xvsjw6wd7cm4tmh4gprfmhxue69uhhyetvv9ujumt0wd68ymewdejhgam0wf4scqjs3l';
    const testUrl = 'nostr:$testNevent';

    test('should decode nevent and extract event ID', () {
      final result = NostrUtils.decodeNevent(testNevent);
      
      expect(result, isA<Map<String, dynamic>>());
      expect(result['eventId'], isA<String>());
      expect(result['relays'], isA<List<String>>());
      expect((result['eventId'] as String).isNotEmpty, isTrue);
      expect(result['eventId'], equals('5be3996545548c139d1dd44f81122adedf0eb10851c4cc849da737d8dd57bbd5'));
      expect(result['relays'], contains('wss://relay.mostro.network'));
    });

    test('should validate nostr URL correctly', () {
      final isValid = NostrUtils.isValidNostrUrl(testUrl);
      expect(isValid, isTrue);
    });

    test('should parse nostr URL correctly', () {
      final result = NostrUtils.parseNostrUrl(testUrl);
      
      expect(result, isNotNull);
      expect(result!['eventId'], isA<String>());
      expect((result['eventId'] as String).isNotEmpty, isTrue);
      expect(result['eventId'], equals('5be3996545548c139d1dd44f81122adedf0eb10851c4cc849da737d8dd57bbd5'));
    });

  });

  group('NostrUtils mostro URL tests', () {
    const testOrderId = 'order123456';
    const testRelays = 'wss://relay.mostro.network,wss://relay.damus.io';
    const testMostroUrl = 'mostro:$testOrderId?relays=$testRelays';

    test('should validate mostro URL correctly', () {
      expect(NostrUtils.isValidMostroUrl(testMostroUrl), isTrue);
    });

    test('should reject invalid mostro URLs', () {
      expect(NostrUtils.isValidMostroUrl('mostro:'), isFalse);
      expect(NostrUtils.isValidMostroUrl('mostro:order123'), isFalse); // no relays
      expect(NostrUtils.isValidMostroUrl('mostro:?relays=wss://relay.com'), isFalse); // no order id
      expect(NostrUtils.isValidMostroUrl('nostr:order123?relays=wss://relay.com'), isFalse); // wrong scheme
      expect(NostrUtils.isValidMostroUrl('mostro:order123?relays=http://relay.com'), isFalse); // invalid relay protocol
    });

    test('should parse mostro URL correctly', () {
      final result = NostrUtils.parseMostroUrl(testMostroUrl);
      
      expect(result, isNotNull);
      expect(result!['orderId'], equals(testOrderId));
      expect(result['relays'], isA<List<String>>());
      expect(result['relays'], contains('wss://relay.mostro.network'));
      expect(result['relays'], contains('wss://relay.damus.io'));
      expect((result['relays'] as List).length, equals(2));
    });

    test('should handle single relay in mostro URL', () {
      const singleRelayUrl = 'mostro:order789?relays=wss://relay.mostro.network';
      final result = NostrUtils.parseMostroUrl(singleRelayUrl);
      
      expect(result, isNotNull);
      expect(result!['orderId'], equals('order789'));
      expect(result['relays'], equals(['wss://relay.mostro.network']));
    });

    test('should handle relays with spaces', () {
      const spacedRelaysUrl = 'mostro:order456?relays=wss://relay1.com, wss://relay2.com , wss://relay3.com';
      final result = NostrUtils.parseMostroUrl(spacedRelaysUrl);
      
      expect(result, isNotNull);
      expect(result!['relays'], equals(['wss://relay1.com', 'wss://relay2.com', 'wss://relay3.com']));
    });

    test('should return null for invalid mostro URLs', () {
      expect(NostrUtils.parseMostroUrl('invalid:url'), isNull);
      expect(NostrUtils.parseMostroUrl('mostro:'), isNull);
      expect(NostrUtils.parseMostroUrl('mostro:order123'), isNull); // no relays
    });

  });
}