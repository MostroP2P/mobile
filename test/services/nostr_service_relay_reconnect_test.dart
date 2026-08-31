import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/services/nostr_service.dart';

/// An idle reconnected socket carries no REQs and therefore sends no data, so
/// `onRelayListening` alone can never observe the reconnect: the REQ replay is
/// what would produce the first frame. The reconnect probe polls the registry
/// and bumps the relay generation only once the socket is verifiably open —
/// after which SubscriptionManager replays the open REQs onto it.
void main() {
  const relayUrl = 'wss://relay.test';

  late NostrService service;
  late bool socketOpen;
  late List<int> emissions;
  late StreamSubscription<int> subscription;

  setUp(() {
    service = NostrService();
    service.reconnectProbeInterval = const Duration(milliseconds: 10);
    socketOpen = false;
    service.relaySocketProbeOverride = (_) => socketOpen;
    emissions = <int>[];
    subscription = service.relayGenerationStream.listen(emissions.add);
  });

  tearDown(() async {
    await subscription.cancel();
  });

  test('no generation bump while the dropped socket stays down', () async {
    service.watchRelayReconnect(relayUrl);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(service.relayGeneration, 0);
    expect(emissions, isEmpty);
    expect(service.connectedRelays, isNot(contains(relayUrl)));
  });

  test('generation bumps once the socket is verifiably open again', () async {
    service.watchRelayReconnect(relayUrl);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    socketOpen = true;
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(service.relayGeneration, 1);
    expect(emissions, [1]);
    expect(service.connectedRelays, contains(relayUrl));
  });

  test('re-watching the same relay replaces the probe and bumps once',
      () async {
    service.watchRelayReconnect(relayUrl);
    service.watchRelayReconnect(relayUrl);

    socketOpen = true;
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(service.relayGeneration, 1);
    expect(emissions, [1]);
  });
}
