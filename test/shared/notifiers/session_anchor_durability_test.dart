import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/order/settlement_terms_store.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mocks.mocks.dart';

/// A trade is published the moment newSession returns, so "the anchors are
/// durable before the commitment goes out" has to mean the call fails when
/// they are not. A best-effort write here puts a live remote trade behind
/// terms that exist only in memory.
void main() {
  final keyPair = NostrKeyPairs(
    private:
        '0000000000000000000000000000000000000000000000000000000000000001',
  );

  late MockKeyManager keyManager;
  late MockSessionStorage storage;
  late _FailingWritePrefs prefs;
  late ProviderContainer container;
  late SessionNotifier notifier;

  setUp(() async {
    keyManager = MockKeyManager();
    storage = MockSessionStorage();
    prefs = _FailingWritePrefs();

    when(keyManager.masterKeyPair).thenReturn(keyPair);
    when(keyManager.getCurrentKeyIndex()).thenAnswer((_) async => 1);
    when(keyManager.deriveTradeKey()).thenAnswer((_) async => keyPair);
    when(storage.putSession(any)).thenAnswer((_) async {});

    container = ProviderContainer(overrides: [
      keyManagerProvider.overrideWith((ref) => keyManager),
      settlementTermsStoreProvider
          .overrideWithValue(SettlementTermsStore(prefs)),
    ]);
    addTearDown(container.dispose);
    await container.read(settlementTermsStoreProvider).init();

    // Built through a provider so it gets a real Ref, which is what it reads
    // the anchor store through.
    notifier = container.read(
      Provider<SessionNotifier>(
        (ref) => SessionNotifier(
          ref,
          storage,
          Settings(
            relays: const [],
            fullPrivacyMode: false,
            mostroPublicKey: 'a' * 64,
            defaultFiatCode: 'USD',
            selectedLanguage: 'en',
          ),
        ),
      ),
    );
  });

  group('newSession when the anchors cannot be stored', () {
    test('throws instead of handing back a session to publish', () async {
      await expectLater(
        notifier.newSession(
          orderId: 'order-1',
          role: Role.buyer,
          pinnedAmountSats: 100000,
          pinnedFeeRate: 0.006,
        ),
        throwsA(isA<SettlementTermsNotDurable>()),
      );
    });

    test('registers no session for the trade it refused', () async {
      await expectLater(
        notifier.newSession(orderId: 'order-1', role: Role.buyer),
        throwsA(isA<SettlementTermsNotDurable>()),
      );

      expect(notifier.getSessionByOrderId('order-1'), isNull);
      expect(notifier.sessions, isEmpty);
      verifyNever(storage.putSession(any));
    });

    test('goes through once storage recovers', () async {
      prefs.failWrites = false;

      final session = await notifier.newSession(
        orderId: 'order-1',
        role: Role.buyer,
        pinnedAmountSats: 100000,
      );

      expect(session.termsPinned, isTrue);
      expect(notifier.getSessionByOrderId('order-1'), isNotNull);
      verify(storage.putSession(any)).called(1);
    });
  });

  group('createChildOrderSession when the anchors cannot be stored', () {
    test('still prepares the child, so the release is not blocked', () async {
      // The release carrying NextTrade is what moves money out of escrow.
      // Refusing it because the remainder's anchor could not be written
      // trades the important thing for the incidental one, and leaves funds
      // stuck with nothing published and nothing to retry.
      final session = await notifier.createChildOrderSession(
        tradeKey: keyPair,
        keyIndex: 2,
        parentOrderId: 'order-1',
        role: Role.seller,
        pinnedFeeRate: 0.006,
        pinnedFiatCode: 'USD',
        pinnedPremium: 0,
        termsPinned: true,
      );

      expect(notifier.getSessionByTradeKey(keyPair.public), isNotNull);
      expect(session.parentOrderId, 'order-1');
    });

    test('marks the child legacy rather than claiming terms it did not store',
        () async {
      // Left as termsPinned with the figures in place, the remainder would
      // report anchors that survive nothing.
      final session = await notifier.createChildOrderSession(
        tradeKey: keyPair,
        keyIndex: 2,
        parentOrderId: 'order-1',
        role: Role.seller,
        pinnedFeeRate: 0.006,
        pinnedFiatCode: 'USD',
        pinnedPremium: 0,
        termsPinned: true,
      );

      expect(session.termsPinned, isFalse);
      expect(session.pinnedFeeRate, isNull);
      expect(session.pinnedFiatCode, isNull);
      expect(session.pinnedPremium, isNull);
    });

    test('keeps the parent terms when the anchor does land', () async {
      prefs.failWrites = false;

      final session = await notifier.createChildOrderSession(
        tradeKey: keyPair,
        keyIndex: 2,
        parentOrderId: 'order-1',
        role: Role.seller,
        pinnedFeeRate: 0.006,
        pinnedFiatCode: 'USD',
        pinnedPremium: 0,
        termsPinned: true,
      );

      expect(session.termsPinned, isTrue);
      expect(session.pinnedFeeRate, 0.006);
      expect(session.pinnedFiatCode, 'USD');
    });
  });
}

/// Writes fail until [failWrites] is cleared.
// ignore: must_be_immutable
class _FailingWritePrefs implements SharedPreferencesAsync {
  bool failWrites = true;
  String? _stored;

  @override
  Future<String?> getString(String key, {Object? options}) async => _stored;

  @override
  Future<void> setString(String key, String value, {Object? options}) async {
    if (failWrites) throw StateError('disk full');
    _stored = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
