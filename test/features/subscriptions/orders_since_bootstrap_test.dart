import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../mocks.mocks.dart';

/// First launch after upgrading to the cursor build: sessions exist but no
/// `orders_since_` preference does. A flat default lookback would silently
/// drop responses to orders older than it — non-terminal orders are kept far
/// longer, and normal startup does not run the restore flow — so the
/// bootstrap window must also reach back to the oldest live session.
const _mostroPubkey = 'mostro-pubkey';
const _tradeKey =
    'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';

void main() {
  late MockNostrService nostrService;
  late MockOpenOrdersRepository orderRepository;
  late ProviderContainer container;
  late _FakeSessionNotifier sessions;
  late SubscriptionManager manager;
  late List<NostrRequest> issuedRequests;
  late StreamController<int> relayGenerations;

  Session sessionStartedAt(DateTime startTime) => Session(
        masterKey: NostrKeyPairs(
            private:
                '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'),
        tradeKey: NostrKeyPairs(private: _tradeKey),
        keyIndex: 0,
        fullPrivacy: false,
        startTime: startTime,
      )..orderId = 'order-a';

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    nostrService = MockNostrService();
    orderRepository = MockOpenOrdersRepository();
    issuedRequests = <NostrRequest>[];
    var nextSubscriptionId = 0;
    when(nostrService.subscribeToEvents(any)).thenAnswer((invocation) {
      final request = invocation.positionalArguments.first as NostrRequest;
      request.subscriptionId ??= 'sub-${nextSubscriptionId++}';
      issuedRequests.add(request);
      return const Stream<NostrEvent>.empty();
    });
    when(nostrService.unsubscribe(any)).thenAnswer((_) async {});
    relayGenerations = StreamController<int>.broadcast();
    when(nostrService.relayGenerationStream)
        .thenAnswer((_) => relayGenerations.stream);
    when(nostrService.relayGeneration).thenAnswer((_) => 0);
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
    manager.unsubscribeAll();
    container.dispose();
    relayGenerations.close();
  });

  Future<DateTime> ordersSinceFor(DateTime sessionStart) async {
    container.read(sessionNotifierProvider);
    manager = container.read(subscriptionManagerProvider);
    sessions.emit([sessionStartedAt(sessionStart)]);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final ordersFilter = issuedRequests
        .expand((r) => r.filters)
        .firstWhere((f) =>
            (f.kinds ?? const []).contains(14) &&
            (f.authors ?? const []).contains(_mostroPubkey));
    expect(ordersFilter.since, isNotNull);
    return ordersFilter.since!;
  }

  test('with no cursor the window reaches back to the oldest session',
      () async {
    final start = DateTime.now().subtract(const Duration(days: 45));

    final since = await ordersSinceFor(start);

    expect(since.isAfter(start), isFalse,
        reason: 'a response to a 45-day-old order must still be replayed');
  });

  test('a young session does not narrow the window below the lookback',
      () async {
    final since = await ordersSinceFor(DateTime.now());

    final lookbackFloor = DateTime.now()
        .subtract(NostrEventExtensions.chatDefaultLookback)
        .subtract(const Duration(minutes: 1));
    expect(since.isAfter(lookbackFloor), isFalse,
        reason: 'fresh installs keep the default lookback');
  });
}

class _FixedSettingsNotifier extends SettingsNotifier {
  _FixedSettingsNotifier() : super(MockSharedPreferencesAsync()) {
    state = Settings(
      relays: const [],
      fullPrivacyMode: false,
      mostroPublicKey: _mostroPubkey,
    );
  }
}

class _FakeSessionNotifier extends SessionNotifier {
  _FakeSessionNotifier(Ref ref)
      : super(ref, MockSessionStorage(), MockSettings()) {
    state = const [];
  }

  void emit(List<Session> sessions) => state = sessions;
}
