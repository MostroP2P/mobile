import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/features/notifications/utils/notification_data_extractor.dart';
import 'package:mostro_mobile/features/notifications/utils/notification_message_mapper.dart';

void main() {
  group('NotificationMessageMapper', () {
    test('returns timeout-specific message key for expired counterparty cancellations', () {
      final key = NotificationMessageMapper.getMessageKeyWithContext(
        Action.canceled,
        const {'cancellation_reason': 'peer_timeout'},
      );

      expect(key, 'notification_order_canceled_peer_timeout_message');
    });

    test('keeps generic cancellation copy for other canceled orders', () {
      final key = NotificationMessageMapper.getMessageKeyWithContext(
        Action.canceled,
        const {},
      );

      expect(key, 'notification_order_canceled_message');
    });
  });

  group('NotificationDataExtractor', () {
    test('tags maker-side timeout cancellations with peer_timeout reason', () async {
      final message = MostroMessage(
        id: 'order-123',
        action: Action.canceled,
        payload: const Order(
          id: 'order-123',
          kind: OrderType.sell,
          status: Status.pending,
          fiatCode: 'USD',
          fiatAmount: 100,
          paymentMethod: 'Cash',
        ),
      );

      final session = Session(
        masterKey: NostrKeyPairs(private: '1' * 64, public: '2' * 64),
        tradeKey: NostrKeyPairs(private: '3' * 64, public: '4' * 64),
        keyIndex: 0,
        fullPrivacy: false,
        startTime: DateTime.utc(2026, 1, 1),
        orderId: 'order-123',
        role: Role.seller,
      );

      final notification = await NotificationDataExtractor.extractFromMostroMessage(
        message,
        null,
        session: session,
      );

      expect(notification, isNotNull);
      expect(notification!.action, Action.canceled);
      expect(notification.values['cancellation_reason'], 'peer_timeout');
    });

    test('does not tag cancellations after a peer was established', () async {
      final message = MostroMessage(
        id: 'order-123',
        action: Action.canceled,
        payload: const Order(
          id: 'order-123',
          kind: OrderType.sell,
          status: Status.pending,
          fiatCode: 'USD',
          fiatAmount: 100,
          paymentMethod: 'Cash',
          buyerTradePubkey: '5' * 64,
        ),
      );

      final session = Session(
        masterKey: NostrKeyPairs(private: '1' * 64, public: '2' * 64),
        tradeKey: NostrKeyPairs(private: '3' * 64, public: '4' * 64),
        keyIndex: 0,
        fullPrivacy: false,
        startTime: DateTime.utc(2026, 1, 1),
        orderId: 'order-123',
        role: Role.seller,
        peer: Peer(publicKey: '5' * 64),
      );

      final notification = await NotificationDataExtractor.extractFromMostroMessage(
        message,
        null,
        session: session,
      );

      expect(notification, isNotNull);
      expect(notification!.values.containsKey('cancellation_reason'), isFalse);
    });
  });
}
