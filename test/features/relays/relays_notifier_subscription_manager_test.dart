import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/core/models/relay_list_event.dart';
import 'package:mostro_mobile/features/relays/relay.dart';
import 'package:mostro_mobile/features/relays/relays_provider.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../mocks.mocks.dart';

/// Regression guard: `RelaysNotifier` must consume the app-wide
/// `subscriptionManagerProvider` instead of constructing its own
/// `SubscriptionManager`. A private instance duplicated every orders/chat/
/// dispute REQ on every relay (and every history replay) for the lifetime of
/// the app, since nothing consumed those streams.
void main() {
  late StreamController<RelayListEvent> relayListController;
  late MockSubscriptionManagerSpy sharedManager;
  late ProviderContainer container;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    relayListController = StreamController<RelayListEvent>.broadcast();
    sharedManager = MockSubscriptionManagerSpy();
    when(sharedManager.relayList)
        .thenAnswer((_) => relayListController.stream);
    container = ProviderContainer(overrides: [
      sharedPreferencesProvider
          .overrideWithValue(SharedPreferencesAsync()),
      subscriptionManagerProvider.overrideWithValue(sharedManager),
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

  testWidgets(
      'applies relay lists received through the shared SubscriptionManager',
      (tester) async {
    // Arrange
    container.read(relaysProvider);
    await tester.pump();

    // Act
    relayListController.add(RelayListEvent(
      relays: const ['wss://relay.mostro.test'],
      publishedAt: DateTime.now(),
      authorPubkey: Config.mostroPubKey,
    ));
    await tester.pump();

    // Assert
    final relays = container.read(relaysProvider);
    expect(
      relays.where((r) => r.url == 'wss://relay.mostro.test'),
      hasLength(1),
      reason: 'the relay list must be consumed from the shared manager, '
          'not from a privately constructed SubscriptionManager',
    );
    expect(
      relays.firstWhere((r) => r.url == 'wss://relay.mostro.test').source,
      RelaySource.mostro,
    );

    await tearDownContainer(tester);
  });

  testWidgets('does not dispose the shared SubscriptionManager it borrows',
      (tester) async {
    // Arrange
    container.read(relaysProvider);
    await tester.pump();

    // Act
    await tearDownContainer(tester);

    // Assert
    verifyNever(sharedManager.dispose());
  });
}
