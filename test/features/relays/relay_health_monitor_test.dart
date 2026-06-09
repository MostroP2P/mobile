import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/features/relays/relay_health_monitor.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';

import '../../mocks.mocks.dart';

/// Settings notifier with a fixed Mostro pubkey and operating relay list.
class _FixedSettingsNotifier extends SettingsNotifier {
  _FixedSettingsNotifier({
    String pubkey = 'test',
    List<String> relays = const [],
  }) : super(MockSharedPreferencesAsync()) {
    state = Settings(
      relays: relays,
      fullPrivacyMode: false,
      mostroPublicKey: pubkey,
    );
  }
}

void main() {
  late MockNostrService nostrService;
  late MockSubscriptionManagerSpy subscriptionManager;

  setUp(() {
    nostrService = MockNostrService();
    subscriptionManager = MockSubscriptionManagerSpy();
    when(nostrService.ensureBootstrapConnectivity()).thenAnswer((_) async {});
    when(nostrService.isInitialized).thenReturn(true);
    when(nostrService.connectedRelays).thenReturn(<String>{});
  });

  ProviderContainer buildContainer({
    String pubkey = 'test',
    List<String> relays = const [],
  }) {
    final container = ProviderContainer(overrides: [
      nostrServiceProvider.overrideWithValue(nostrService),
      subscriptionManagerProvider.overrideWithValue(subscriptionManager),
      settingsProvider.overrideWith(
          (ref) => _FixedSettingsNotifier(pubkey: pubkey, relays: relays)),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  group('RelayHealthMonitor', () {
    test('engages bootstrap and re-subscribes when no operating relay is alive',
        () async {
      // Operating relay configured but not connected.
      when(nostrService.connectedRelays).thenReturn(<String>{});

      final monitor = buildContainer(relays: ['wss://discovered.example.com'])
          .read(relayHealthMonitorProvider);
      await monitor.checkNow();

      verify(nostrService.ensureBootstrapConnectivity()).called(1);
      verify(subscriptionManager.subscribeAll()).called(1);
      verify(subscriptionManager.subscribeToMostroRelayList('test')).called(1);
    });

    test('stays idle while an operating relay is alive', () async {
      when(nostrService.connectedRelays)
          .thenReturn({'wss://discovered.example.com'});

      final monitor = buildContainer(relays: ['wss://discovered.example.com'])
          .read(relayHealthMonitorProvider);
      await monitor.checkNow();

      verifyNever(nostrService.ensureBootstrapConnectivity());
      verifyNever(subscriptionManager.subscribeAll());
    });

    test(
        'still recovers when only a bootstrap relay is alive '
        '(does not mask a dead discovered layer)', () async {
      // A bootstrap relay is connected, but the operating (discovered) relay is
      // not. The watchdog must NOT treat this as healthy.
      when(nostrService.connectedRelays).thenReturn({'wss://relay.damus.io'});

      final monitor = buildContainer(relays: ['wss://discovered.example.com'])
          .read(relayHealthMonitorProvider);
      await monitor.checkNow();

      verify(nostrService.ensureBootstrapConnectivity()).called(1);
      verify(subscriptionManager.subscribeAll()).called(1);
    });

    test('does nothing before NostrService is initialized', () async {
      when(nostrService.isInitialized).thenReturn(false);

      final monitor = buildContainer(relays: ['wss://discovered.example.com'])
          .read(relayHealthMonitorProvider);
      await monitor.checkNow();

      verifyNever(nostrService.ensureBootstrapConnectivity());
      verifyNever(subscriptionManager.subscribeAll());
    });

    test('skips relay-list re-subscription when no Mostro is configured',
        () async {
      final monitor =
          buildContainer(pubkey: '').read(relayHealthMonitorProvider);
      await monitor.checkNow();

      verify(nostrService.ensureBootstrapConnectivity()).called(1);
      verify(subscriptionManager.subscribeAll()).called(1);
      verifyNever(subscriptionManager.subscribeToMostroRelayList(any));
    });
  });
}
