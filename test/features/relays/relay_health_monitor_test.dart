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

/// Settings notifier with a fixed Mostro pubkey for tests.
class _FixedSettingsNotifier extends SettingsNotifier {
  _FixedSettingsNotifier(String pubkey) : super(MockSharedPreferencesAsync()) {
    state = Settings(
      relays: const [],
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
    when(nostrService.ensureBootstrapConnectivity())
        .thenAnswer((_) async {});
  });

  ProviderContainer buildContainer({String pubkey = 'test'}) {
    final container = ProviderContainer(overrides: [
      nostrServiceProvider.overrideWithValue(nostrService),
      subscriptionManagerProvider.overrideWithValue(subscriptionManager),
      settingsProvider.overrideWith((ref) => _FixedSettingsNotifier(pubkey)),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  group('RelayHealthMonitor', () {
    test('engages bootstrap and re-subscribes when no relay is alive',
        () async {
      when(nostrService.isInitialized).thenReturn(true);
      when(nostrService.liveRelayCount).thenReturn(0);

      final monitor =
          buildContainer().read(relayHealthMonitorProvider);
      await monitor.checkNow();

      verify(nostrService.ensureBootstrapConnectivity()).called(1);
      verify(subscriptionManager.subscribeAll()).called(1);
      verify(subscriptionManager.subscribeToMostroRelayList('test')).called(1);
    });

    test('does nothing while at least one relay is alive', () async {
      when(nostrService.isInitialized).thenReturn(true);
      when(nostrService.liveRelayCount).thenReturn(2);

      final monitor =
          buildContainer().read(relayHealthMonitorProvider);
      await monitor.checkNow();

      verifyNever(nostrService.ensureBootstrapConnectivity());
      verifyNever(subscriptionManager.subscribeAll());
    });

    test('does nothing before NostrService is initialized', () async {
      when(nostrService.isInitialized).thenReturn(false);
      when(nostrService.liveRelayCount).thenReturn(0);

      final monitor =
          buildContainer().read(relayHealthMonitorProvider);
      await monitor.checkNow();

      verifyNever(nostrService.ensureBootstrapConnectivity());
      verifyNever(subscriptionManager.subscribeAll());
    });

    test('skips relay-list re-subscription when no Mostro is configured',
        () async {
      when(nostrService.isInitialized).thenReturn(true);
      when(nostrService.liveRelayCount).thenReturn(0);

      final monitor =
          buildContainer(pubkey: '').read(relayHealthMonitorProvider);
      await monitor.checkNow();

      verify(nostrService.ensureBootstrapConnectivity()).called(1);
      verify(subscriptionManager.subscribeAll()).called(1);
      verifyNever(subscriptionManager.subscribeToMostroRelayList(any));
    });
  });
}
