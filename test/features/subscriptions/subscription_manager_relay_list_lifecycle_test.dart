import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_type.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';

import '../../mocks.mocks.dart';

/// The relay-list subscription is the one subscription `SubscriptionManager`
/// cannot rebuild from sessions: `_createFilterForType` returns null for it and
/// `subscribeAll()` therefore leaves it closed. That was harmless while
/// `RelaysNotifier` owned a private manager, but once it borrows the app-wide
/// one, `LifecycleManager` tears it down on every background switch.
class _FixedSettingsNotifier extends SettingsNotifier {
  _FixedSettingsNotifier() : super(MockSharedPreferencesAsync()) {
    state = Settings(
      relays: const [],
      fullPrivacyMode: false,
      mostroPublicKey: 'mostro-pubkey',
    );
  }
}

/// Session list the manager can read without touching storage.
class _FakeSessionNotifier extends SessionNotifier {
  _FakeSessionNotifier(Ref ref)
      : super(ref, MockSessionStorage(), MockSettings()) {
    state = const [];
  }

  void emit(List<Session> sessions) => state = sessions;
}

void main() {
  const pubkey = 'mostro-pubkey';

  late MockNostrService nostrService;
  late MockOpenOrdersRepository orderRepository;
  late ProviderContainer container;
  late _FakeSessionNotifier sessions;
  late SubscriptionManager manager;
  var nextSubscriptionId = 0;

  setUp(() {
    nostrService = MockNostrService();
    orderRepository = MockOpenOrdersRepository();

    nextSubscriptionId = 0;
    when(nostrService.subscribeToEvents(any)).thenAnswer((invocation) {
      // The real service stamps the id while serialising the REQ; without one
      // Subscription.cancel() throws on `subscriptionId!`.
      final request = invocation.positionalArguments.first as NostrRequest;
      request.subscriptionId ??= 'sub-${nextSubscriptionId++}';
      return const Stream<NostrEvent>.empty();
    });
    when(nostrService.unsubscribe(any)).thenAnswer((_) async {});
    when(orderRepository.mostroInstanceStream)
        .thenAnswer((_) => const Stream<NostrEvent>.empty());
    when(orderRepository.mostroInstance).thenReturn(null);

    container = ProviderContainer(overrides: [
      nostrServiceProvider.overrideWithValue(nostrService),
      orderRepositoryProvider.overrideWithValue(orderRepository),
      settingsProvider.overrideWith((ref) => _FixedSettingsNotifier()),
      sessionNotifierProvider.overrideWith((ref) {
        sessions = _FakeSessionNotifier(ref);
        return sessions;
      }),
    ]);
  });

  tearDown(() {
    // Release the REQs while the container can still resolve NostrService;
    // SubscriptionManager.dispose() runs after the container is torn down.
    manager.unsubscribeAll();
    container.dispose();
  });

  SubscriptionManager buildManager() {
    // Materialise the session notifier before the manager listens to it.
    container.read(sessionNotifierProvider);
    manager = container.read(subscriptionManagerProvider);
    return manager;
  }

  bool hasRelayList(SubscriptionManager m) =>
      m.hasActiveSubscription(SubscriptionType.relayList);

  group('relay-list subscription across the lifecycle', () {
    // Regression test for the P1 raised on #683: `subscribeAll()` cannot
    // rebuild the relay list, so a plain background/foreground cycle left the
    // app permanently deaf to kind 10002 updates.
    test('survives a background/foreground cycle', () {
      buildManager();
      manager.subscribeToMostroRelayList(pubkey);
      expect(hasRelayList(manager), isTrue);

      manager.suspend();
      expect(hasRelayList(manager), isFalse,
          reason: 'backgrounding must release the REQ');

      manager.resume();
      expect(hasRelayList(manager), isTrue,
          reason: 'foreground recovery must re-open the relay list');
    });

    test('survives a bare subscribeAll (relay health recovery)', () {
      buildManager();
      manager.subscribeToMostroRelayList(pubkey);

      manager.subscribeAll();

      expect(hasRelayList(manager), isTrue);
    });

    // Sessions are unrelated to relay discovery; losing every session must not
    // stop the app from learning about relays.
    test('survives the session list going empty', () async {
      buildManager();
      manager.subscribeToMostroRelayList(pubkey);

      sessions.emit([]);
      await Future<void>.delayed(Duration.zero);

      expect(hasRelayList(manager), isTrue);
    });

    // Raised by CodeRabbit on #683: the retry timer in `RelaysNotifier` can
    // fire after the app has been backgrounded.
    test('a pending retry while backgrounded does not re-open the REQ', () {
      buildManager();
      manager.subscribeToMostroRelayList(pubkey);
      manager.suspend();

      // What RelaysNotifier._scheduleRetrySync() does 10 s later.
      manager.subscribeToMostroRelayList(pubkey);

      expect(hasRelayList(manager), isFalse,
          reason: 'the background service owns connectivity while suspended');

      manager.resume();
      expect(hasRelayList(manager), isTrue,
          reason: 'the deferred request must still be honoured on resume');
    });

    test('an explicit unsubscribe is not undone by a later resume', () {
      buildManager();
      manager.subscribeToMostroRelayList(pubkey);
      manager.unsubscribeFromMostroRelayList();

      manager.suspend();
      manager.resume();

      expect(hasRelayList(manager), isFalse);
    });
  });
}
