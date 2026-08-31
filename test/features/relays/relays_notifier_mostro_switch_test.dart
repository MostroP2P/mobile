import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/core/models/relay_list_event.dart';
import 'package:mostro_mobile/features/relays/relays_provider.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../mocks.mocks.dart';

/// Switching Mostro instance must wipe the previous instance's relays.
///
/// That reset used to be driven by a `Timer.periodic(5 s)` polling
/// `settings.state.mostroPublicKey`; it is now a `ref.listen` on the same
/// value. The listener is registered inside a `try/catch` (fake refs in unit
/// tests), so a wiring mistake would not throw — it would silently leave the
/// app talking to the old instance's relays. This pins the behaviour.
void main() {
  late StreamController<RelayListEvent> relayListController;
  late MockSubscriptionManagerSpy sharedManager;
  late MockNostrService nostrService;
  late ProviderContainer container;

  const otherMostro =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    relayListController = StreamController<RelayListEvent>.broadcast();
    sharedManager = MockSubscriptionManagerSpy();
    when(sharedManager.relayList).thenAnswer((_) => relayListController.stream);
    nostrService = MockNostrService();
    when(nostrService.ensureBootstrapConnectivity())
        .thenAnswer((_) async {});
    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(SharedPreferencesAsync()),
      subscriptionManagerProvider.overrideWithValue(sharedManager),
      nostrServiceProvider.overrideWithValue(nostrService),
    ]);
  });

  /// The notifier's deferred sync polls NostrService for up to 10 s and then
  /// schedules a 10 s retry; let those timers elapse so the test binding's
  /// "no pending timers" invariant holds.
  Future<void> tearDownContainer(WidgetTester tester) async {
    container.dispose();
    await relayListController.close();
    await tester.pump(const Duration(seconds: 30));
  }

  /// Puts one relay published by the currently configured instance into the
  /// notifier's state.
  Future<void> seedCurrentInstanceRelay(WidgetTester tester) async {
    container.read(relaysProvider);
    await tester.pump();
    relayListController.add(RelayListEvent(
      relays: const ['wss://relay.old-mostro.test'],
      publishedAt: DateTime.now(),
      authorPubkey: Config.mostroPubKey,
    ));
    await tester.pump();
    expect(
      container.read(relaysProvider).where(
            (r) => r.url == 'wss://relay.old-mostro.test',
          ),
      hasLength(1),
      reason: 'precondition: the old instance relay is in the list',
    );
  }

  testWidgets('a Mostro pubkey change clears the previous instance relays',
      (tester) async {
    // Arrange: the current instance published a relay list.
    await seedCurrentInstanceRelay(tester);

    // Act: switch node, exactly as MostroNodesNotifier.selectNode does.
    await container
        .read(settingsProvider.notifier)
        .updateMostroInstance(otherMostro);
    await tester.pump();

    // Assert
    expect(
      container.read(relaysProvider).where(
            (r) => r.url == 'wss://relay.old-mostro.test',
          ),
      isEmpty,
      reason: 'the new instance never published this relay; keeping it would '
          'leak the previous Mostro instance across the switch',
    );
    verify(nostrService.ensureBootstrapConnectivity()).called(1);

    await tearDownContainer(tester);
  });

  testWidgets('clearing the Mostro pubkey also tears the old instance down',
      (tester) async {
    // Arrange
    await seedCurrentInstanceRelay(tester);

    // The constructor's deferred sync already unsubscribed once; only the
    // calls caused by clearing the pubkey are of interest here.
    clearInteractions(sharedManager);

    // Act: drop the configured instance entirely.
    await container.read(settingsProvider.notifier).updateMostroInstance('');
    await tester.pump();

    // Assert: syncWithMostroInstance() bails out on an empty pubkey before it
    // reaches its own unsubscribe/prune, so this transition has to be torn
    // down explicitly — otherwise the relays and the kind 10002 REQ of an
    // instance the app is no longer configured for stay alive.
    expect(
      container.read(relaysProvider).where(
            (r) => r.url == 'wss://relay.old-mostro.test',
          ),
      isEmpty,
      reason: 'no instance is configured, so no instance relay may remain',
    );
    verify(sharedManager.unsubscribeFromMostroRelayList()).called(1);

    await tearDownContainer(tester);
  });
}
