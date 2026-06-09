import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/services/nostr_service.dart';

void main() {
  group('NostrService relay health surface', () {
    test('a fresh service reports no live relays', () {
      final service = NostrService();

      expect(service.isInitialized, isFalse);
      expect(service.liveRelayCount, 0);
      expect(service.connectedRelays, isEmpty);
    });

    test('settings getter falls back to an empty relay list', () {
      final service = NostrService();

      expect(service.settings.relays, isEmpty);
    });

    test('connectedRelays is an unmodifiable view', () {
      final service = NostrService();

      expect(
        () => service.connectedRelays.add('wss://relay.example.com'),
        throwsUnsupportedError,
      );
    });
  });

  group('bootstrap relay configuration', () {
    test('bootstrap relays are non-empty secure websocket urls', () {
      expect(Config.bootstrapRelays, isNotEmpty);
      for (final url in Config.bootstrapRelays) {
        expect(url.startsWith('wss://'), isTrue, reason: '$url must be wss://');
      }
    });

    test('relay discovery timeout is a positive grace period', () {
      expect(Config.relayDiscoveryTimeout, greaterThan(Duration.zero));
    });
  });
}
