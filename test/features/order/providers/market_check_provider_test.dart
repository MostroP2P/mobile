import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/order/providers/market_check_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/services/exchange_service.dart';
import 'package:mostro_mobile/shared/utils/market_quote.dart';

import '../../../mocks.mocks.dart';

const _orderId = 'order-1';

final _keyPair = NostrKeyPairs(
  private: '0000000000000000000000000000000000000000000000000000000000000001',
);

/// The kind-38383 order event, resolved to the figures a settlement is priced
/// from: sats, currency, fiat amount and premium.
NostrEvent _orderEvent({
  String amount = '200000',
  String currency = 'USD',
  List<String> fiat = const ['fa', '100'],
  String premium = '0',
}) =>
    NostrEvent(
      id: 'order-event',
      kind: 38383,
      content: '',
      sig: 'sig',
      pubkey: 'a' * 64,
      createdAt: DateTime.utc(2026),
      tags: [
        ['d', _orderId],
        ['amt', amount],
        ['f', currency],
        fiat,
        ['premium', premium],
      ],
    );

Session _session({int? pinnedAmountSats, bool termsPinned = true}) => Session(
      masterKey: _keyPair,
      tradeKey: _keyPair,
      keyIndex: 0,
      fullPrivacy: false,
      startTime: DateTime.utc(2026),
      orderId: _orderId,
      pinnedAmountSats: pinnedAmountSats,
      termsPinned: termsPinned,
    );

void main() {
  late MockOpenOrdersRepository repository;
  late StreamController<List<NostrEvent>> orderEvents;
  late Session? session;
  late double? independentRate;
  late ProviderContainer container;

  void build() {
    container = ProviderContainer(overrides: [
      orderRepositoryProvider.overrideWithValue(repository),
      sessionProvider.overrideWith((ref, id) => id == _orderId ? session : null),
      independentFiatPerBtcProvider
          .overrideWith((ref, code) async => independentRate),
    ]);
    addTearDown(container.dispose);

    // Both providers are autoDispose now, so a bare read would build and tear
    // down an instance per call and restart the rate request every time. A
    // live listener is what a mounted screen is.
    container.listen(marketCheckProvider(_orderId), (_, __) {},
        fireImmediately: true);
  }

  /// Publishes [event] and lets the provider chain settle on it.
  Future<void> publish(NostrEvent event) async {
    orderEvents.add([event]);
    await container.read(independentFiatPerBtcProvider('USD').future);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    repository = MockOpenOrdersRepository();
    orderEvents = StreamController<List<NostrEvent>>.broadcast();
    when(repository.eventsStream).thenAnswer((_) => orderEvents.stream);

    session = _session();
    // $50,000 per bitcoin: the $100 order above is worth 200,000 sats.
    independentRate = 50000;
    build();

    addTearDown(orderEvents.close);
  });

  group('marketCheckProvider', () {
    test('says nothing about an order settling at the market rate', () async {
      container.read(marketCheckProvider(_orderId));
      await publish(_orderEvent());

      final result = container.read(marketCheckProvider(_orderId));
      expect(result.status, MarketCheckStatus.checked);
      expect(result.check!.quotedSats, 200000);
      expect(result.check!.isOffMarket, isFalse);
    });

    test('catches the node shaving the settlement', () async {
      container.read(marketCheckProvider(_orderId));
      await publish(_orderEvent(amount: '180000'));

      final check = container.read(marketCheckProvider(_orderId)).check!;
      expect(check.isOffMarket, isTrue);
      expect(check.isBelowMarket, isTrue);
      expect(check.settledSats, 180000);
    });

    test('accounts for the premium before judging', () async {
      container.read(marketCheckProvider(_orderId));
      await publish(_orderEvent(amount: '180000', premium: '10'));

      expect(container.read(marketCheckProvider(_orderId)).check!.isOffMarket,
          isFalse);
    });

    test('skips an order whose sats the session pinned', () async {
      // A fixed-amount order was shown to the user and pinned at commitment,
      // so it is held to that figure and may sit off the market on purpose.
      session = _session(pinnedAmountSats: 180000);
      build();

      container.read(marketCheckProvider(_orderId));
      await publish(_orderEvent(amount: '180000'));

      expect(container.read(marketCheckProvider(_orderId)).status,
          MarketCheckStatus.notApplicable);
    });

    test('skips a session written before pinning existed', () async {
      // A session from an earlier build pinned no sats, so without a marker of
      // its own it is indistinguishable from a market-price order the node
      // resolved. Checking it would put a caution on any fixed-amount trade
      // in flight when the user updated, priced by hand and off the market on
      // purpose.
      session = _session(termsPinned: false);
      build();

      container.read(marketCheckProvider(_orderId));
      await publish(_orderEvent(amount: '180000'));

      expect(container.read(marketCheckProvider(_orderId)).status,
          MarketCheckStatus.notApplicable);
    });

    test('skips an order with no session of its own', () async {
      session = null;
      build();

      container.read(marketCheckProvider(_orderId));
      await publish(_orderEvent(amount: '180000'));

      expect(container.read(marketCheckProvider(_orderId)).status,
          MarketCheckStatus.notApplicable);
    });

    test('skips a range order that has not been resolved to one figure',
        () async {
      container.read(marketCheckProvider(_orderId));
      await publish(_orderEvent(fiat: const ['fa', '50', '200']));

      expect(container.read(marketCheckProvider(_orderId)).status,
          MarketCheckStatus.notApplicable);
    });

    test('reports a rate that cannot be had as a check it could not make',
        () async {
      // Not the same as a settlement that passed: the screens say so rather
      // than opening the flow on silence.
      independentRate = null;
      build();

      container.read(marketCheckProvider(_orderId));
      await publish(_orderEvent(amount: '180000'));

      expect(container.read(marketCheckProvider(_orderId)).status,
          MarketCheckStatus.unavailable);
    });

    test('reports an empty currency tag as a check it could not make',
        () async {
      // The node publishes this tag and can empty it, so silence here would
      // be a state it can put the screen into.
      container.read(marketCheckProvider(_orderId));
      await publish(_orderEvent(currency: ''));

      expect(container.read(marketCheckProvider(_orderId)).status,
          MarketCheckStatus.unavailable);
    });

    test('skips before the order event has arrived', () {
      expect(container.read(marketCheckProvider(_orderId)).status,
          MarketCheckStatus.notApplicable);
    });

    test('reports an unreadable premium as a check it could not make',
        () async {
      // Quoting an unreadable premium as zero would misprice the order by
      // exactly the premium and turn an honest trade into a refusal.
      container.read(marketCheckProvider(_orderId));
      await publish(_orderEvent(amount: '180000', premium: 'not-a-number'));

      expect(container.read(marketCheckProvider(_orderId)).status,
          MarketCheckStatus.unavailable);
    });

    test('treats an absent premium as zero', () async {
      container.read(marketCheckProvider(_orderId));
      await publish(_orderEvent(premium: ''));

      final check = container.read(marketCheckProvider(_orderId)).check!;
      expect(check.quotedSats, 200000);
    });

    test('reports a rate still in flight as loading, not as no gap', () async {
      // The gap the finding describes: a request that has not come back read
      // the same as a settlement priced correctly, so the screens opened
      // before the check had an answer.
      final rate = Completer<double?>();
      container = ProviderContainer(overrides: [
        orderRepositoryProvider.overrideWithValue(repository),
        sessionProvider
            .overrideWith((ref, id) => id == _orderId ? session : null),
        independentFiatPerBtcProvider.overrideWith((ref, code) => rate.future),
      ]);
      addTearDown(container.dispose);
      container.listen(marketCheckProvider(_orderId), (_, __) {},
          fireImmediately: true);

      orderEvents.add([_orderEvent(amount: '180000')]);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(marketCheckProvider(_orderId)).status,
          MarketCheckStatus.loading);

      rate.complete(50000);
      await Future<void>.delayed(Duration.zero);

      final settled = container.read(marketCheckProvider(_orderId));
      expect(settled.status, MarketCheckStatus.checked);
      expect(settled.check!.isOffMarket, isTrue);
    });
  });

  group('the independent rate', () {
    test('is fetched again for a later settlement rather than reused', () async {
      // Not autoDispose, the first rate a process ever fetched went on
      // pricing every trade after it, however many hours later.
      var fetches = 0;
      final container = ProviderContainer(overrides: [
        independentExchangeServiceProvider
            .overrideWithValue(_CountingExchangeService(() => fetches++)),
      ]);
      addTearDown(container.dispose);

      final first = container.listen(
        independentFiatPerBtcProvider('USD'),
        (_, __) {},
      );
      await container.read(independentFiatPerBtcProvider('USD').future);
      expect(fetches, 1);

      // The settlement screen goes away, and with it the last listener.
      first.close();
      await Future<void>.delayed(Duration.zero);

      container.listen(independentFiatPerBtcProvider('USD'), (_, __) {});
      await container.read(independentFiatPerBtcProvider('USD').future);
      expect(fetches, 2);
    });
  });
}

/// Counts how many times a rate is actually asked for.
class _CountingExchangeService implements ExchangeService {
  _CountingExchangeService(this.onFetch);

  final void Function() onFetch;

  @override
  Future<double> getExchangeRate(String from, String to) async {
    onFetch();
    return 50000;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
