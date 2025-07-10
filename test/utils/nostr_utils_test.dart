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
}