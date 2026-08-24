import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/features/order/providers/settlement_anchor_provider.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';

import '../../../mocks.mocks.dart';

final _nodePubkey = 'a' * 64;
final _otherNodePubkey = 'b' * 64;
const _orderId = 'order-1';

/// The kind-38385 info event, carrying only the tags the fee rate is read
/// from. `MostroInstance.fee` parses the `fee` tag eagerly and throws when it
/// is absent, which is what the provider's guard is there to absorb.
NostrEvent _infoEvent({String? pubkey, String? fee}) => NostrEvent(
      id: 'info-event',
      kind: 38385,
      content: '',
      sig: 'sig',
      pubkey: pubkey ?? _nodePubkey,
      createdAt: DateTime.utc(2026),
      tags: [
        ['d', pubkey ?? _nodePubkey],
        if (fee != null) ['fee', fee],
      ],
    );

/// The kind-38383 order event the signed amount is read from.
NostrEvent _orderEvent({String amount = '100000'}) => NostrEvent(
      id: 'order-event',
      kind: 38383,
      content: '',
      sig: 'sig',
      pubkey: _nodePubkey,
      createdAt: DateTime.utc(2026),
      tags: [
        ['d', _orderId],
        ['amt', amount],
      ],
    );

final _keyPair = NostrKeyPairs(
  private: '0000000000000000000000000000000000000000000000000000000000000001',
);

/// The session for [_orderId], carrying whatever it pinned when it committed.
Session _session({int? pinnedAmountSats, double? pinnedFeeRate}) => Session(
      masterKey: _keyPair,
      tradeKey: _keyPair,
      keyIndex: 0,
      fullPrivacy: false,
      startTime: DateTime.utc(2026),
      orderId: _orderId,
      pinnedAmountSats: pinnedAmountSats,
      pinnedFeeRate: pinnedFeeRate,
    );

/// Settings that can be pointed at another node without touching storage.
class _StubSettingsNotifier extends SettingsNotifier {
  _StubSettingsNotifier(String mostroPublicKey)
      : super(MockSharedPreferencesAsync()) {
    state = Settings(
      relays: const [],
      fullPrivacyMode: false,
      mostroPublicKey: mostroPublicKey,
      defaultFiatCode: 'USD',
      selectedLanguage: null,
    );
  }

  void useNode(String mostroPublicKey) {
    state = state.copyWith(mostroPublicKey: mostroPublicKey);
  }
}

void main() {
  late MockOpenOrdersRepository repository;
  late StreamController<NostrEvent> infoEvents;
  late StreamController<List<NostrEvent>> orderEvents;
  late _StubSettingsNotifier settings;
  late Session? session;
  late ProviderContainer container;

  /// Rebuilds the container so a session set by a test is in place before the
  /// providers first read it.
  void build() {
    container = ProviderContainer(overrides: [
      orderRepositoryProvider.overrideWithValue(repository),
      settingsProvider.overrideWith((ref) => settings),
      sessionProvider.overrideWith((ref, id) => id == _orderId ? session : null),
    ]);
    addTearDown(container.dispose);
  }

  /// Lets the stream deliveries behind the providers settle.
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  setUp(() {
    repository = MockOpenOrdersRepository();
    infoEvents = StreamController<NostrEvent>.broadcast();
    orderEvents = StreamController<List<NostrEvent>>.broadcast();
    when(repository.mostroInstance).thenReturn(null);
    when(repository.mostroInstanceStream).thenAnswer((_) => infoEvents.stream);
    when(repository.eventsStream).thenAnswer((_) => orderEvents.stream);

    settings = _StubSettingsNotifier(_nodePubkey);
    session = null;
    build();

    addTearDown(infoEvents.close);
    addTearDown(orderEvents.close);
  });

  group('nodeFeeRateProvider', () {
    test('reports the fee once a late info event arrives', () async {
      expect(container.read(nodeFeeRateProvider), isNull);

      infoEvents.add(_infoEvent(fee: '0.006'));
      await flush();

      expect(container.read(nodeFeeRateProvider), 0.006);
    });

    test('reports the fee of an event that arrived before the first read',
        () async {
      when(repository.mostroInstance).thenReturn(_infoEvent(fee: '0.006'));

      container.read(nodeFeeRateProvider);
      await flush();

      expect(container.read(nodeFeeRateProvider), 0.006);
    });

    test('stays null when the info event carries no fee tag', () async {
      container.read(nodeFeeRateProvider);
      infoEvents.add(_infoEvent());
      await flush();

      expect(container.read(nodeFeeRateProvider), isNull);
    });

    test('drops the previous node fee when the selected node changes',
        () async {
      container.read(nodeFeeRateProvider);
      infoEvents.add(_infoEvent(fee: '0.006'));
      await flush();
      expect(container.read(nodeFeeRateProvider), 0.006);

      settings.useNode(_otherNodePubkey);
      expect(container.read(nodeFeeRateProvider), isNull);

      infoEvents.add(_infoEvent(pubkey: _otherNodePubkey, fee: '0.002'));
      await flush();
      expect(container.read(nodeFeeRateProvider), 0.002);
    });
  });

  group('anchored settlement amounts', () {
    test('resolve once the order and info events have both arrived', () async {
      expect(container.read(anchoredSellerAmountProvider(_orderId)), isNull);
      expect(container.read(anchoredBuyerAmountProvider(_orderId)), isNull);

      orderEvents.add([_orderEvent()]);
      infoEvents.add(_infoEvent(fee: '0.006'));
      await flush();

      // 100000 sats, each side paying half of the 0.6% fee: 300 sats.
      expect(container.read(anchoredSellerAmountProvider(_orderId)), 100300);
      expect(container.read(anchoredBuyerAmountProvider(_orderId)), 99700);
    });

    test('stay null while only the order event has arrived', () async {
      expect(container.read(anchoredSellerAmountProvider(_orderId)), isNull);

      orderEvents.add([_orderEvent()]);
      await flush();

      expect(container.read(anchoredSellerAmountProvider(_orderId)), isNull);
      expect(container.read(anchoredBuyerAmountProvider(_orderId)), isNull);
    });
  });

  group('terms pinned at commitment', () {
    test('holds the settlement to the pinned amount, not the republished one',
        () async {
      session = _session(pinnedAmountSats: 100000);
      build();

      container.read(anchoredSellerAmountProvider(_orderId));
      // The node republishes its order event asking for five times as much.
      orderEvents.add([_orderEvent(amount: '500000')]);
      infoEvents.add(_infoEvent(fee: '0.006'));
      await flush();

      expect(container.read(anchoredSellerAmountProvider(_orderId)), 100300);
      expect(container.read(anchoredBuyerAmountProvider(_orderId)), 99700);
    });

    test('holds the settlement to the pinned fee rate', () async {
      session = _session(pinnedFeeRate: 0.006);
      build();

      container.read(anchoredSellerAmountProvider(_orderId));
      orderEvents.add([_orderEvent()]);
      // The node now advertises a fee rate more than sixteen times higher.
      infoEvents.add(_infoEvent(fee: '0.1'));
      await flush();

      expect(container.read(orderFeeRateProvider(_orderId)), 0.006);
      expect(container.read(anchoredSellerAmountProvider(_orderId)), 100300);
    });

    test('resolves from the live events when nothing was pinned', () async {
      session = _session();
      build();

      container.read(anchoredSellerAmountProvider(_orderId));
      orderEvents.add([_orderEvent()]);
      infoEvents.add(_infoEvent(fee: '0.006'));
      await flush();

      // A market-price or range order pins no sats figure, so it stays on the
      // live events and depends on the market check instead.
      expect(container.read(anchoredSellerAmountProvider(_orderId)), 100300);
    });

    test('ignores a pinned amount that is not a usable figure', () async {
      session = _session(pinnedAmountSats: 0);
      build();

      container.read(anchoredSellerAmountProvider(_orderId));
      orderEvents.add([_orderEvent()]);
      infoEvents.add(_infoEvent(fee: '0.006'));
      await flush();

      expect(container.read(anchoredSellerAmountProvider(_orderId)), 100300);
    });
  });
}
