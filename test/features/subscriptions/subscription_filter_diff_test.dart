import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/data/models/peer.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager.dart';
import 'package:mostro_mobile/services/chat_cursor_store.dart';
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
const _mostroPubkey = 'mostro-pubkey';

void main() {
  late MockNostrService nostrService;
  late MockOpenOrdersRepository orderRepository;
  late ProviderContainer container;
  late _FakeSessionNotifier sessions;
  late SubscriptionManager manager;
  late StreamController<int> relayGenerations;
  late List<NostrRequest> issuedRequests;
  var relayGeneration = 0;
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
    issuedRequests = <NostrRequest>[];
    when(nostrService.subscribeToEvents(any)).thenAnswer((invocation) {
      final request = invocation.positionalArguments.first as NostrRequest;
      request.subscriptionId ??= 'sub-${nextSubscriptionId++}';
      issuedRequests.add(request);
      return const Stream<NostrEvent>.empty();
    });
    when(nostrService.unsubscribe(any)).thenAnswer((_) async {});
    relayGenerations = StreamController<int>.broadcast();
    relayGeneration = 0;
    when(nostrService.relayGenerationStream)
        .thenAnswer((_) => relayGenerations.stream);
    when(nostrService.relayGeneration).thenAnswer((_) => relayGeneration);
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

  test('a relay coming alive re-issues the REQs for unchanged sessions',
      () async {
    // dart_nostr sends a REQ only to the sockets registered at subscription
    // time: a reconnected socket or a relay added by the 10002 sync comes up
    // subscription-less. The generation bump must force a re-issue even
    // though the session set (and thus the filter content) is unchanged.
    await buildWithSession();

    relayGeneration = 1;
    relayGenerations.add(1);
    await Future<void>.delayed(SubscriptionManager.relayResubscribeDebounce +
        const Duration(milliseconds: 200));

    verify(nostrService.subscribeToEvents(any)).called(1);
  });

  test('relay come-alive bursts coalesce into a single re-issue', () async {
    await buildWithSession();

    relayGeneration = 1;
    relayGenerations.add(1);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    relayGeneration = 2;
    relayGenerations.add(2);
    await Future<void>.delayed(SubscriptionManager.relayResubscribeDebounce +
        const Duration(milliseconds: 200));

    verify(nostrService.subscribeToEvents(any)).called(1);
  });

  test(
      'identical chat emissions during a slow cursor warm-up issue a single '
      'chat REQ', () async {
    // The chat path awaits ChatCursorStore.warmUp before recording its
    // filter key. Two identical bursty emissions used to both pass the
    // identity check while the first was still warming up, each replaying
    // the CLOSE + REQ.
    container.dispose();
    container = ProviderContainer(overrides: [
      nostrServiceProvider.overrideWithValue(nostrService),
      orderRepositoryProvider.overrideWithValue(orderRepository),
      settingsProvider.overrideWith((ref) => _FixedSettingsNotifier()),
      chatCursorStoreProvider.overrideWithValue(_SlowWarmUpCursorStore()),
      sessionNotifierProvider.overrideWith((ref) {
        sessions = _FakeSessionNotifier(ref);
        return sessions;
      }),
    ]);
    container.read(sessionNotifierProvider);
    manager = container.read(subscriptionManagerProvider);

    final peerPubkey = NostrKeyPairs(private: keyB).public;
    Session chatSession() =>
        session('order-a', keyA)..peer = Peer(publicKey: peerPubkey);

    // Back-to-back emissions of the same session set, no flush in between —
    // the second arrives while the first is still awaiting warmUp.
    sessions.emit([chatSession()]);
    sessions.emit([chatSession()]);

    // Deterministic on slow CI machines: wait for the first chat REQ to be
    // issued instead of assuming a fixed delay is enough, then allow a settle
    // window in which a duplicated REQ would land.
    // The orders REQ is kind 14 too since the transport defaults to v2, so
    // match on the author instead of the kind alone: chat filters are keyed
    // on the peer-derived K_sign pubkeys, never on the node's pubkey.
    bool isChatRequest(NostrRequest r) => r.filters.any((f) =>
        (f.kinds ?? []).contains(14) &&
        !(f.authors ?? const []).contains(_mostroPubkey));
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!issuedRequests.any(isChatRequest) &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final chatRequests = issuedRequests.where(isChatRequest).toList();
    expect(chatRequests, hasLength(1));
    verifyNever(nostrService.unsubscribe(any));
  });
}

/// Chat cursor store whose warm-up stays pending across event-loop turns,
/// widening the race window between the identity check and the REQ.
class _SlowWarmUpCursorStore extends ChatCursorStore {
  _SlowWarmUpCursorStore()
      : super(MockSharedPreferencesAsync(),
            keyPrefix: ChatCursorStore.peerKeyPrefix);

  @override
  Future<void> warmUp(Iterable<String> conversationIds) =>
      Future<void>.delayed(const Duration(milliseconds: 5));
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

/// Session list the manager can read without touching storage.
class _FakeSessionNotifier extends SessionNotifier {
  _FakeSessionNotifier(Ref ref)
      : super(ref, MockSessionStorage(), MockSettings()) {
    state = const [];
  }

  void emit(List<Session> sessions) => state = sessions;
}
