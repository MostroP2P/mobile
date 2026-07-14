import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:mostro_mobile/features/order/notifiers/abstract_mostro_notifier.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/navigation_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';

import '../../../mocks.dart';
import '../../../mocks.mocks.dart';

/// Regression coverage for the notification freshness gate swap: both gate
/// call sites in `AbstractMostroNotifier` (subscribe()'s check and
/// handleEvent()'s `isRecent`) must key off `receivedAt` (true client arrival
/// time) instead of `timestamp` (protocol/send time). The single most
/// important scenario here is the reconnect-after-offline case: an old
/// protocol `timestamp` must NOT suppress a message that is genuinely new to
/// this client.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const orderId = 'freshness-gate-order';
  var dbCounter = 0;

  late ProviderContainer container;
  late StreamController<MostroMessage?> messageController;
  late AbstractMostroNotifier notifier;

  Session buildSession() {
    return Session(
      masterKey: NostrKeyPairs(
          private:
              '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'),
      tradeKey: NostrKeyPairs(
          private:
              'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890'),
      keyIndex: 0,
      fullPrivacy: false,
      startTime: DateTime.now(),
      orderId: orderId,
      role: Role.buyer,
    );
  }

  Future<void> flushAsyncOperations() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() async {
    dbCounter++;
    final db = await databaseFactoryMemory
        .openDatabase('freshness_gate_test_$dbCounter.db');
    messageController = StreamController<MostroMessage?>.broadcast();

    final mockKeyManager = MockKeyManager();
    final mockSessionStorage = MockSessionStorage();
    final mockSettings = MockSettings();
    final mockRef = MockRef();
    final mockSessionNotifier = MockSessionNotifier(
        mockRef, mockKeyManager, mockSessionStorage, mockSettings);
    mockSessionNotifier.setMockSession(buildSession());

    container = ProviderContainer(overrides: [
      mostroDatabaseProvider.overrideWithValue(db),
      mostroMessageStreamProvider
          .overrideWith((ref, id) => messageController.stream),
      sessionNotifierProvider.overrideWith((ref) => mockSessionNotifier),
    ]);

    final ref = container.read(Provider<Ref>((ref) => ref));
    notifier = AbstractMostroNotifier(orderId, ref);
    notifier.subscribe();
  });

  tearDown(() async {
    notifier.dispose();
    container.dispose();
    await messageController.close();
  });

  group('AbstractMostroNotifier freshness gate (receivedAt-based)', () {
    test('recent receivedAt passes the gate and fires a notification',
        () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final message = MostroMessage<PaymentFailed>(
        id: orderId,
        action: Action.paymentFailed,
        payload:
            PaymentFailed(paymentAttempts: 1, paymentRetriesInterval: 60),
        timestamp: now,
        receivedAt: now,
      );

      messageController.add(message);
      await flushAsyncOperations();

      final temporary = container.read(currentTemporaryNotificationProvider);
      expect(temporary.show, isTrue);
      expect(temporary.action, Action.paymentFailed);
    });

    test(
        'old protocol timestamp with a recent receivedAt still passes the '
        'gate (reconnect-after-offline regression)', () async {
      final oldTimestamp = DateTime.now()
          .subtract(const Duration(minutes: 10))
          .millisecondsSinceEpoch;
      final recentReceivedAt = DateTime.now().millisecondsSinceEpoch;
      final message = MostroMessage<PaymentFailed>(
        id: orderId,
        action: Action.paymentFailed,
        payload:
            PaymentFailed(paymentAttempts: 1, paymentRetriesInterval: 60),
        timestamp: oldTimestamp,
        receivedAt: recentReceivedAt,
      );

      messageController.add(message);
      await flushAsyncOperations();

      final temporary = container.read(currentTemporaryNotificationProvider);
      expect(temporary.show, isTrue,
          reason: 'A message with an old protocol timestamp but a fresh '
              'receivedAt must still be notified — this is the exact bug '
              'this change fixes.');
      expect(temporary.action, Action.paymentFailed);
    });

    test(
        'old receivedAt fails the gate: no notification, but state still '
        'updates unconditionally', () async {
      final oldReceivedAt = DateTime.now()
          .subtract(const Duration(minutes: 10))
          .millisecondsSinceEpoch;
      final message = MostroMessage<PaymentFailed>(
        id: orderId,
        action: Action.paymentFailed,
        payload:
            PaymentFailed(paymentAttempts: 2, paymentRetriesInterval: 30),
        timestamp: DateTime.now().millisecondsSinceEpoch,
        receivedAt: oldReceivedAt,
      );

      messageController.add(message);
      await flushAsyncOperations();

      final temporary = container.read(currentTemporaryNotificationProvider);
      expect(temporary.show, isFalse);

      expect(notifier.state.action, Action.paymentFailed);
      expect(notifier.state.status, Status.paymentFailed);
    });

    test(
        'dispute action bypasses the gate for state processing despite an '
        'old receivedAt, but still suppresses notification and navigation',
        () async {
      final oldReceivedAt = DateTime.now()
          .subtract(const Duration(minutes: 10))
          .millisecondsSinceEpoch;
      final dispute = Dispute(disputeId: 'dispute-1', status: 'initiated');
      final message = MostroMessage<Dispute>(
        id: orderId,
        action: Action.disputeInitiatedByPeer,
        payload: dispute,
        timestamp: oldReceivedAt,
        receivedAt: oldReceivedAt,
      );

      final pathBefore = container.read(navigationProvider).path;

      messageController.add(message);
      await flushAsyncOperations();

      // Notification is suppressed for the old event.
      expect(container.read(currentTemporaryNotificationProvider).show,
          isFalse);
      // Navigation is suppressed too (isRecent is false, bypassTimestampGate
      // is true).
      expect(container.read(navigationProvider).path, pathBefore);
      // Yet handleEvent still processed the dispute action (state-only):
      // orderId/action are only stamped by handleEvent's dispute branch, not
      // by the unconditional updateWith() merge, so this proves the bypass
      // actually ran despite the old receivedAt.
      expect(notifier.state.dispute, isNotNull);
      expect(notifier.state.dispute!.orderId, orderId);
      expect(notifier.state.dispute!.action, 'dispute-initiated-by-peer');
    });
  });
}
