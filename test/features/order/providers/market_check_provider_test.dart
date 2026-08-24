import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/order/providers/market_check_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';

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

Session _session({int? pinnedAmountSats}) => Session(
      masterKey: _keyPair,
      tradeKey: _keyPair,
      keyIndex: 0,
      fullPrivacy: false,
      startTime: DateTime.utc(2026),
      orderId: _orderId,
      pinnedAmountSats: pinnedAmountSats,
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

      final check = container.read(marketCheckProvider(_orderId))!;
      expect(check.quotedSats, 200000);
      expect(check.isOffMarket, isFalse);
    });

    test('catches the node shaving the settlement', () async {
      container.read(marketCheckProvider(_orderId));
      await publish(_orderEvent(amount: '180000'));

      final check = container.read(marketCheckProvider(_orderId))!;
      expect(check.isOffMarket, isTrue);
      expect(check.isBelowMarket, isTrue);
      expect(check.settledSats, 180000);
    });

    test('accounts for the premium before judging', () async {
      container.read(marketCheckProvider(_orderId));
      await publish(_orderEvent(amount: '180000', premium: '10'));

      expect(container.read(marketCheckProvider(_orderId))!.isOffMarket,
          isFalse);
    });

    test('skips an order whose sats the session pinned', () async {
      // A fixed-amount order was shown to the user and pinned at commitment,
      // so it is held to that figure and may sit off the market on purpose.
      session = _session(pinnedAmountSats: 180000);
      build();

      container.read(marketCheckProvider(_orderId));
      await publish(_orderEvent(amount: '180000'));

      expect(container.read(marketCheckProvider(_orderId)), isNull);
    });

    test('skips a range order that has not been resolved to one figure',
        () async {
      container.read(marketCheckProvider(_orderId));
      await publish(_orderEvent(fiat: const ['fa', '50', '200']));

      expect(container.read(marketCheckProvider(_orderId)), isNull);
    });

    test('skips when the independent rate cannot be had', () async {
      independentRate = null;
      build();

      container.read(marketCheckProvider(_orderId));
      await publish(_orderEvent(amount: '180000'));

      expect(container.read(marketCheckProvider(_orderId)), isNull);
    });

    test('skips before the order event has arrived', () {
      expect(container.read(marketCheckProvider(_orderId)), isNull);
    });

    test('skips an order whose premium cannot be read', () async {
      // Quoting an unreadable premium as zero would misprice the order by
      // exactly the premium and turn an honest trade into a refusal.
      container.read(marketCheckProvider(_orderId));
      await publish(_orderEvent(amount: '180000', premium: 'not-a-number'));

      expect(container.read(marketCheckProvider(_orderId)), isNull);
    });

    test('treats an absent premium as zero', () async {
      container.read(marketCheckProvider(_orderId));
      await publish(_orderEvent(premium: ''));

      final check = container.read(marketCheckProvider(_orderId))!;
      expect(check.quotedSats, 200000);
    });
  });
}
