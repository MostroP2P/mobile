import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/features/relays/relays_notifier.dart';

import '../../mocks.dart';

void main() {
  group('RelaysNotifier', () {
    late RelaysNotifier notifier;
    late MockSettingsNotifier mockSettings;
    
    setUp(() {
      mockSettings = MockSettingsNotifier();
      notifier = RelaysNotifier(mockSettings);
    });
    
    group('normalizeRelayUrl', () {
      test('should accept valid wss:// URLs', () {
        expect(notifier.normalizeRelayUrl('wss://relay.mostro.network'), 
               'wss://relay.mostro.network');
        expect(notifier.normalizeRelayUrl('WSS://RELAY.EXAMPLE.COM'), 
               'wss://relay.example.com');
        expect(notifier.normalizeRelayUrl('  wss://relay.test.com  '), 
               'wss://relay.test.com');
      });

      test('should add wss:// prefix to domain-only inputs', () {
        expect(notifier.normalizeRelayUrl('relay.mostro.network'), 
               'wss://relay.mostro.network');
        expect(notifier.normalizeRelayUrl('example.com'), 
               'wss://example.com');
        expect(notifier.normalizeRelayUrl('sub.domain.example.org'), 
               'wss://sub.domain.example.org');
      });

      test('should reject non-secure websockets', () {
        expect(notifier.normalizeRelayUrl('ws://relay.example.com'), null);
        expect(notifier.normalizeRelayUrl('WS://RELAY.TEST.COM'), null);
      });

      test('should reject http URLs', () {
        expect(notifier.normalizeRelayUrl('http://example.com'), null);
        expect(notifier.normalizeRelayUrl('https://example.com'), null);
        expect(notifier.normalizeRelayUrl('HTTP://EXAMPLE.COM'), null);
      });

      test('should reject invalid formats', () {
        expect(notifier.normalizeRelayUrl('holahola'), null);
        expect(notifier.normalizeRelayUrl('not-a-domain'), null);
        expect(notifier.normalizeRelayUrl(''), null);
        expect(notifier.normalizeRelayUrl('   '), null);
        expect(notifier.normalizeRelayUrl('invalid..domain'), null);
        expect(notifier.normalizeRelayUrl('.example.com'), null);
        expect(notifier.normalizeRelayUrl('example.'), null);
      });

      test('should handle edge cases', () {
        expect(notifier.normalizeRelayUrl('localhost.local'), 'wss://localhost.local');
        expect(notifier.normalizeRelayUrl('192.168.1.1'), null); // IP without domain
        expect(notifier.normalizeRelayUrl('test'), null); // No dot
        expect(notifier.normalizeRelayUrl('test.'), null); // Ends with dot
      });
    });

    group('isValidDomainFormat', () {
      test('should accept valid domains', () {
        expect(notifier.isValidDomainFormat('relay.mostro.network'), true);
        expect(notifier.isValidDomainFormat('example.com'), true);
        expect(notifier.isValidDomainFormat('sub.domain.example.org'), true);
        expect(notifier.isValidDomainFormat('wss://relay.example.com'), true);
        expect(notifier.isValidDomainFormat('test-relay.example.com'), true);
        expect(notifier.isValidDomainFormat('a.b'), true);
      });

      test('should reject invalid domains', () {
        expect(notifier.isValidDomainFormat('holahola'), false);
        expect(notifier.isValidDomainFormat('invalid..domain'), false);
        expect(notifier.isValidDomainFormat('.example.com'), false);
        expect(notifier.isValidDomainFormat('example.'), false);
        expect(notifier.isValidDomainFormat(''), false);
        expect(notifier.isValidDomainFormat('test'), false); // No dot
        expect(notifier.isValidDomainFormat('-example.com'), false);
        expect(notifier.isValidDomainFormat('example-.com'), false);
      });

      test('should handle protocol prefixes correctly', () {
        expect(notifier.isValidDomainFormat('wss://relay.example.com'), true);
        expect(notifier.isValidDomainFormat('ws://relay.example.com'), true);
        expect(notifier.isValidDomainFormat('http://relay.example.com'), true);
        expect(notifier.isValidDomainFormat('https://relay.example.com'), true);
      });
    });

    group('addRelayWithSmartValidation', () {
      test('should return error for invalid domain format', () async {
        final result = await notifier.addRelayWithSmartValidation(
          'holahola',
          errorOnlySecure: 'Only secure websockets (wss://) are allowed',
          errorNoHttp: 'HTTP URLs are not supported. Use websocket URLs (wss://)',
          errorInvalidDomain: 'Invalid domain format. Use format like: relay.example.com',
          errorAlreadyExists: 'This relay is already in your list',
          errorNotValid: 'Not a valid Nostr relay - no response to protocol test',
        );
        expect(result.success, false);
        expect(result.error, contains('Invalid domain format'));
      });

      test('should return error for non-secure websocket', () async {
        final result = await notifier.addRelayWithSmartValidation(
          'ws://relay.example.com',
          errorOnlySecure: 'Only secure websockets (wss://) are allowed',
          errorNoHttp: 'HTTP URLs are not supported. Use websocket URLs (wss://)',
          errorInvalidDomain: 'Invalid domain format. Use format like: relay.example.com',
          errorAlreadyExists: 'This relay is already in your list',
          errorNotValid: 'Not a valid Nostr relay - no response to protocol test',
        );
        expect(result.success, false);
        expect(result.error, contains('Only secure websockets'));
      });

      test('should return error for http URLs', () async {
        final result = await notifier.addRelayWithSmartValidation(
          'http://example.com',
          errorOnlySecure: 'Only secure websockets (wss://) are allowed',
          errorNoHttp: 'HTTP URLs are not supported. Use websocket URLs (wss://)',
          errorInvalidDomain: 'Invalid domain format. Use format like: relay.example.com',
          errorAlreadyExists: 'This relay is already in your list',
          errorNotValid: 'Not a valid Nostr relay - no response to protocol test',
        );
        expect(result.success, false);
        expect(result.error, contains('HTTP URLs are not supported'));
      });

      test('should return error for https URLs', () async {
        final result = await notifier.addRelayWithSmartValidation(
          'https://example.com',
          errorOnlySecure: 'Only secure websockets (wss://) are allowed',
          errorNoHttp: 'HTTP URLs are not supported. Use websocket URLs (wss://)',
          errorInvalidDomain: 'Invalid domain format. Use format like: relay.example.com',
          errorAlreadyExists: 'This relay is already in your list',
          errorNotValid: 'Not a valid Nostr relay - no response to protocol test',
        );
        expect(result.success, false);
        expect(result.error, contains('HTTP URLs are not supported'));
      });
    });

    group('Real relay connectivity tests', () {
      test('should accept valid working relay relay.damus.io', () async {
        final result = await notifier.addRelayWithSmartValidation(
          'relay.damus.io',
          errorOnlySecure: 'Only secure websockets (wss://) are allowed',
          errorNoHttp: 'HTTP URLs are not supported. Use websocket URLs (wss://)',
          errorInvalidDomain: 'Invalid domain format. Use format like: relay.example.com',
          errorAlreadyExists: 'This relay is already in your list',
          errorNotValid: 'Not a valid Nostr relay - no response to protocol test',
        );
        expect(result.success, true, reason: 'relay.damus.io should be accepted as valid');
        expect(result.normalizedUrl, 'wss://relay.damus.io');
        expect(result.isHealthy, true, reason: 'relay.damus.io should respond to protocol test');
      }, timeout: const Timeout(Duration(seconds: 30)));

      test('should reject non-existent relay re.xyz.com', () async {
        final result = await notifier.addRelayWithSmartValidation(
          're.xyz.com',
          errorOnlySecure: 'Only secure websockets (wss://) are allowed',
          errorNoHttp: 'HTTP URLs are not supported. Use websocket URLs (wss://)',
          errorInvalidDomain: 'Invalid domain format. Use format like: relay.example.com',
          errorAlreadyExists: 'This relay is already in your list',
          errorNotValid: 'Not a valid Nostr relay - no response to protocol test',
        );
        expect(result.success, false, reason: 're.xyz.com should be rejected as non-existent');
        expect(result.error, contains('Not a valid Nostr relay'));
      }, timeout: const Timeout(Duration(seconds: 30)));
    });

    group('URL edge cases', () {
      test('should handle various domain formats', () {
        final validCases = [
          'relay.mostro.network',
          'sub.domain.example.com',
          'test-relay.example.org',
          'a.b.c.d.e.com',
          'relay123.example456.com',
        ];
        
        for (final domain in validCases) {
          expect(notifier.normalizeRelayUrl(domain), 'wss://$domain',
                 reason: 'Should accept valid domain: $domain');
        }
      });

      test('should reject invalid domain formats', () {
        final invalidCases = [
          'holahola',
          'not-a-domain',
          'test',
          '-invalid.com',
          'invalid-.com',
          'invalid..com',
          '.invalid.com',
          'invalid.com.',
          '',
          '   ',
        ];
        
        for (final domain in invalidCases) {
          expect(notifier.normalizeRelayUrl(domain), null,
                 reason: 'Should reject invalid domain: $domain');
        }
      });
    });
  });
}