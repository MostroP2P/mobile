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
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';

import '../../mocks.mocks.dart';

/// Every session-list emission tore down and re-issued the orders/chat/
/// dispute REQs on every relay — and `handleEvent` saves the session several
/// times per protocol step. Since the orders filter carries no `since`, each
/// re-issue replayed the full gift-wrap history. The manager now skips the
/// resubscribe when the filter identity (keys, transport, node) is unchanged.
void main() {
  late MockNostrService nostrService;
  late MockOpenOrdersRepository orderRepository;
  late ProviderContainer container;
  late _FakeSessionNotifier sessions;
  late SubscriptionManager manager;
  var nextSubscriptionId = 0;

  Session session(String orderId, String tradeKeyPrivate) {
    final s = Session(
      masterKey: NostrKeyPairs(
          private:
              '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'),
      tradeKey: NostrKeyPairs(private: tradeKeyPrivate),
      keyIndex: 0,
      fullPrivacy: false,
      startTime: DateTime.now(),
    );
    s.orderId = orderId;
    return s;
  }

  const keyA =
      'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';
  const keyB =
      'bbcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';

  setUp(() {
    nostrService = MockNostrService();
    orderRepository = MockOpenOrdersRepository();
    nextSubscriptionId = 0;
    when(nostrService.subscribeToEvents(any)).thenAnswer((invocation) {
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
    manager.unsubscribeAll();
    container.dispose();
  });

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  Future<void> buildWithSession() async {
    container.read(sessionNotifierProvider);
    manager = container.read(subscriptionManagerProvider);
    sessions.emit([session('order-a', keyA)]);
    await flush();
    clearInteractions(nostrService);
  }

  test('an unchanged session set does not re-issue the REQs', () async {
    await buildWithSession();

    // Same order id and trade key, fresh Session instances — what every
    // saveSession/updateSession emission looks like.
    sessions.emit([session('order-a', keyA)]);
    await flush();

    verifyNever(nostrService.subscribeToEvents(any));
    verifyNever(nostrService.unsubscribe(any));
  });

  test('a new trade key re-issues the orders REQ', () async {
    await buildWithSession();

    sessions.emit([session('order-a', keyA), session('order-b', keyB)]);
    await flush();

    verify(nostrService.subscribeToEvents(any)).called(1);
  });

  test('subscribeAll still forces a resubscribe with unchanged sessions',
      () async {
    await buildWithSession();

    manager.subscribeAll();
    await flush();

    verify(nostrService.subscribeToEvents(any)).called(greaterThan(0));
  });
}

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
