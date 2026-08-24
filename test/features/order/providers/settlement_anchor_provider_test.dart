import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/features/order/providers/settlement_anchor_provider.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';

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
  late ProviderContainer container;

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
    container = ProviderContainer(overrides: [
      orderRepositoryProvider.overrideWithValue(repository),
      settingsProvider.overrideWith((ref) => settings),
    ]);

    addTearDown(container.dispose);
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
}
