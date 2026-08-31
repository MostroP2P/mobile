import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/trades/providers/trades_provider.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';

import '../../mocks.mocks.dart';

/// `filteredTradesWithOrderStateProvider` watched the whole session list and
/// sorted the whole order book on every recompute. Any session save (several
/// per protocol step) re-ran it even when the set of the user's order ids was
/// unchanged, returning a fresh list and rebuilding the whole Trades screen.
void main() {
  NostrEvent order(String id, {required int expiration}) => NostrEvent(
        id: 'event-$id',
        kind: 38383,
        content: '',
        sig: '',
        pubkey: 'mostro-pubkey',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000000),
        tags: [
          ['d', id],
          ['z', 'order'],
          ['s', 'pending'],
          ['expiration', '$expiration'],
        ],
      );

  Session session(String orderId) {
    final s = Session(
      masterKey: NostrKeyPairs(
          private:
              '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'),
      tradeKey: NostrKeyPairs(
          private:
              'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890'),
      keyIndex: 0,
      fullPrivacy: false,
      startTime: DateTime.now(),
    );
    s.orderId = orderId;
    return s;
  }

  late _FakeSessionNotifier sessions;
  late ProviderContainer container;

  setUp(() {
    final book = [
      order('a', expiration: 100),
      order('b', expiration: 300),
      order('c', expiration: 200),
    ];
    container = ProviderContainer(overrides: [
      orderEventsProvider.overrideWith((ref) => Stream.value(book)),
      sessionNotifierProvider.overrideWith((ref) {
        sessions = _FakeSessionNotifier(ref);
        return sessions;
      }),
    ]);
    container.listen(filteredTradesWithOrderStateProvider, (_, __) {});
  });

  tearDown(() => container.dispose());

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  test('returns only the sessions\' orders, newest expiration first',
      () async {
    sessions.emit([session('a'), session('b')]);
    await flush();

    final trades =
        container.read(filteredTradesWithOrderStateProvider).value!;
    expect(trades.map((e) => e.orderId), ['b', 'a']);
  });

  test('a session emission with the same order ids does not notify listeners',
      () async {
    sessions.emit([session('a'), session('b')]);
    await flush();
    var notifications = 0;
    container.listen(
        filteredTradesWithOrderStateProvider, (_, __) => notifications++);

    // New list, new Session instances, same order ids — several of these
    // happen per protocol step (saveSession/updateSession).
    sessions.emit([session('a'), session('b')]);
    await flush();

    expect(notifications, 0,
        reason: 'an unchanged order-id set must not rebuild the screen');
  });

  test('a genuinely new session id does notify listeners', () async {
    sessions.emit([session('a')]);
    await flush();
    var notifications = 0;
    container.listen(
        filteredTradesWithOrderStateProvider, (_, __) => notifications++);

    sessions.emit([session('a'), session('c')]);
    await flush();

    expect(notifications, greaterThan(0));
    final trades =
        container.read(filteredTradesWithOrderStateProvider).value!;
    expect(trades.map((e) => e.orderId), ['c', 'a']);
  });
}

/// Session list the provider can read without touching storage.
class _FakeSessionNotifier extends SessionNotifier {
  _FakeSessionNotifier(Ref ref)
      : super(ref, MockSessionStorage(), MockSettings()) {
    state = const [];
  }

  void emit(List<Session> sessions) => state = sessions;
}
