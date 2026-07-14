import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/restore/restore_manager.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/session_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';

import '../../mocks.dart';
import '../../mocks.mocks.dart';

/// Regression coverage requested by review: _reconcileFiatSent must upgrade a
/// stale cooperativeCancelNoFiatByPeer/generic snapshot to
/// cooperativeCancelFiatSentByPeer once a confirming fiat-sent message is
/// found in storage after the restore buffer has drained.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RestoreService - post-flush fiat-sent reconciliation', () {
    late ProviderContainer container;
    late MockMostroService mockMostroService;
    late MockSharedPreferencesAsync mockPreferences;
    late MockOpenOrdersRepository mockOrdersRepository;
    late MockDatabase mockDatabase;
    late MockSessionStorage mockSessionStorage;
    late MockKeyManager mockKeyManager;
    late MockSessionNotifier mockSessionNotifier;
    late MockMostroStorage mockMostroStorage;
    late MockRef ref;

    const testOrderId = 'reconciliation-order-id';

    Order buildOrder() => const Order(
          id: testOrderId,
          kind: OrderType.sell,
          fiatCode: 'USD',
          fiatAmount: 100,
          paymentMethod: 'Lightning',
          amount: 100,
        );

    setUp(() {
      mockMostroService = MockMostroService();
      mockPreferences = MockSharedPreferencesAsync();
      mockOrdersRepository = MockOpenOrdersRepository();
      mockDatabase = MockDatabase();
      mockSessionStorage = MockSessionStorage();
      mockKeyManager = MockKeyManager();
      mockMostroStorage = MockMostroStorage();
      ref = MockRef();

      final testSettings = MockSettings();

      mockSessionNotifier = MockSessionNotifier(
          ref, mockKeyManager, mockSessionStorage, testSettings);

      when(mockKeyManager.masterKeyPair).thenReturn(
        NostrKeyPairs(
            private:
                '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'),
      );
      when(mockKeyManager.getCurrentKeyIndex()).thenAnswer((_) async => 0);

      // Default: no confirming fiat-sent message on file. Overridden per-test.
      when(mockMostroStorage.getAllMessagesForOrderId(any))
          .thenAnswer((_) async => <MostroMessage>[]);

      container = ProviderContainer(overrides: [
        mostroServiceProvider.overrideWithValue(mockMostroService),
        orderRepositoryProvider.overrideWithValue(mockOrdersRepository),
        sharedPreferencesProvider.overrideWithValue(mockPreferences),
        mostroDatabaseProvider.overrideWithValue(mockDatabase),
        eventDatabaseProvider.overrideWithValue(mockDatabase),
        sessionStorageProvider.overrideWithValue(mockSessionStorage),
        keyManagerProvider.overrideWithValue(mockKeyManager),
        sessionNotifierProvider.overrideWith((ref) => mockSessionNotifier),
        settingsProvider.overrideWith((ref) {
          final mockSettings = MockSettingsNotifier();
          mockSettings.state = Settings(
            relays: ['wss://relay.damus.io'],
            fullPrivacyMode: false,
            mostroPublicKey:
                '9d9d0455a96871f2dc4289b8312429db2e925f167b37c77bf7b28014be235980',
            defaultFiatCode: 'USD',
          );
          return mockSettings;
        }),
        mostroStorageProvider.overrideWithValue(mockMostroStorage),
      ]);
    });

    tearDown(() {
      container.dispose();
    });

    test(
        'order regains the release action once a confirming fiat-sent message is found after flush',
        () async {
      // Arrange: apply the base cooperativelyCanceled snapshot exactly like
      // restore()'s per-order loop does (generic action, fiatWasSent still
      // false at this point).
      final coopCancelMessage = MostroMessage<Order>(
        id: testOrderId,
        action: Action.cooperativeCancelInitiatedByPeer,
        payload: buildOrder(),
      );
      final notifier =
          container.read(orderNotifierProvider(testOrderId).notifier);
      notifier.updateStateFromMessage(coopCancelMessage);

      final beforeState = container.read(orderNotifierProvider(testOrderId));
      expect(beforeState.fiatWasSent, isFalse);
      expect(
        beforeState.getActions(Role.seller),
        isNot(contains(Action.release)),
      );

      // Simulate the confirming message becoming visible only after the
      // restore buffer is drained (the race this feature fixes).
      when(mockMostroStorage.getAllMessagesForOrderId(testOrderId))
          .thenAnswer((_) async => [
                MostroMessage<Order>(
                  id: testOrderId,
                  action: Action.fiatSent,
                ),
              ]);

      final restoreService = container.read(restoreServiceProvider);

      // Act
      await restoreService.reconcileFiatSentForTesting([testOrderId]);

      // Assert
      final afterState = container.read(orderNotifierProvider(testOrderId));
      expect(afterState.fiatWasSent, isTrue);
      expect(afterState.action, equals(Action.cooperativeCancelFiatSentByPeer));
      expect(afterState.getActions(Role.seller), contains(Action.release));
    });

    test(
        'corrects a stale NoFiat action even when a live event (not our own snapshot) produced it before reconciliation ran',
        () async {
      // Simulates the Codex-flagged race: a buffered live cooperativeCancel
      // event is flushed and processed by _onData/updateWith BEFORE
      // _reconcileFiatSent runs, so it gets remapped with fiatWasSent still
      // false — same NoFiat outcome as the synthetic snapshot case above,
      // just from a different source message.
      final liveCoopCancelMessage = MostroMessage<Order>(
        id: testOrderId,
        action: Action.cooperativeCancelInitiatedByPeer,
        payload: buildOrder(),
      );
      final notifier =
          container.read(orderNotifierProvider(testOrderId).notifier);
      notifier.updateStateFromMessage(liveCoopCancelMessage);
      expect(
        container.read(orderNotifierProvider(testOrderId)).action,
        equals(Action.cooperativeCancelNoFiatByPeer),
      );

      when(mockMostroStorage.getAllMessagesForOrderId(testOrderId))
          .thenAnswer((_) async => [
                MostroMessage<Order>(id: testOrderId, action: Action.fiatSent),
              ]);

      final restoreService = container.read(restoreServiceProvider);
      await restoreService.reconcileFiatSentForTesting([testOrderId]);

      final afterState = container.read(orderNotifierProvider(testOrderId));
      expect(afterState.fiatWasSent, isTrue);
      expect(afterState.action, equals(Action.cooperativeCancelFiatSentByPeer));
      expect(afterState.getActions(Role.seller), contains(Action.release));
    });
  });
}
