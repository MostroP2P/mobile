import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/features/notifications/services/background_notification_service.dart';
import 'package:mostro_mobile/features/notifications/utils/notification_data_extractor.dart';
import 'package:mostro_mobile/features/notifications/utils/notification_message_mapper.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

/// Tests for the background notification pipeline covering:
/// 1. [NostrUtils.isDmPayload] — pure detection of the `{"dm": ...}` envelope
/// 2. [MostroMessage] construction — synthetic message with [Action.sendDm]
/// 3. [NotificationDataExtractor] — ensures sendDm is NOT marked temporary
/// 4. P2P chat vs admin DM action separation
void main() {
  group('NostrUtils.isDmPayload', () {
    test('detects dm wrapper key in decoded JSON', () {
      final dmPayload = jsonDecode(
        '[{"dm": {"action": "send-dm", "payload": {"text_message": "Hello"}}}]',
      );

      expect(dmPayload, isList);
      expect(dmPayload, isNotEmpty);
      expect(NostrUtils.isDmPayload(dmPayload[0]), isTrue);
    });

    test('does not detect dm key in standard Mostro message', () {
      final orderPayload = jsonDecode(
        '[{"order": {"action": "new-order", "id": "abc123", "payload": null}}]',
      );

      expect(NostrUtils.isDmPayload(orderPayload[0]), isFalse);
    });

    test('does not detect dm key in restore message', () {
      final restorePayload = jsonDecode(
        '[{"restore": {"action": "restore-session", "id": "abc123"}}]',
      );

      expect(NostrUtils.isDmPayload(restorePayload[0]), isFalse);
    });

    test('does not detect dm key in cant-do message', () {
      final cantDoPayload = jsonDecode(
        '[{"cant-do": {"action": "cant-do", "payload": null}}]',
      );

      expect(NostrUtils.isDmPayload(cantDoPayload[0]), isFalse);
    });

    test('returns false for non-Map types', () {
      expect(NostrUtils.isDmPayload('string'), isFalse);
      expect(NostrUtils.isDmPayload(42), isFalse);
      expect(NostrUtils.isDmPayload(null), isFalse);
      expect(NostrUtils.isDmPayload([]), isFalse);
    });

    test('returns false when dm value is not a Map', () {
      expect(NostrUtils.isDmPayload({'dm': 'not-a-map'}), isFalse);
    });

    test('returns false when dm Map has no action', () {
      expect(NostrUtils.isDmPayload({'dm': {}}), isFalse);
    });

    test('returns false when dm action is not send-dm', () {
      expect(
        NostrUtils.isDmPayload({'dm': {'action': 'different-action'}}),
        isFalse,
      );
    });

    test('returns false when payload is null', () {
      expect(
        NostrUtils.isDmPayload({
          'dm': {'action': 'send-dm', 'payload': null}
        }),
        isFalse,
      );
    });

    test('returns false when payload is not a Map', () {
      expect(
        NostrUtils.isDmPayload({
          'dm': {'action': 'send-dm', 'payload': []}
        }),
        isFalse,
      );
      expect(
        NostrUtils.isDmPayload({
          'dm': {'action': 'send-dm', 'payload': 'string'}
        }),
        isFalse,
      );
    });

    test('returns false when dm has action but no payload', () {
      expect(
        NostrUtils.isDmPayload({
          'dm': {'action': 'send-dm'}
        }),
        isFalse,
      );
    });

    test('returns true with valid payload structure', () {
      expect(
        NostrUtils.isDmPayload({
          'dm': {
            'action': 'send-dm',
            'payload': {'text_message': 'Hello admin'}
          }
        }),
        isTrue,
      );
    });
  });

  group('MostroMessage construction for DM', () {
    test('preserves orderId and timestamp with sendDm action', () {
      const testOrderId = 'test-order-123';
      const testTimestamp = 1700000000000;

      final message = MostroMessage(
        action: Action.sendDm,
        id: testOrderId,
        timestamp: testTimestamp,
      );

      expect(message.action, Action.sendDm);
      expect(message.id, testOrderId);
      expect(message.timestamp, testTimestamp);
    });
  });

  group('NotificationDataExtractor for sendDm', () {
    test('produces non-temporary notification data', () async {
      final message = MostroMessage(
        action: Action.sendDm,
        id: 'order-abc',
        timestamp: 1700000000000,
      );

      final data = await NotificationDataExtractor.extractFromMostroMessage(
        message,
        null,
      );

      expect(data, isNotNull);
      expect(data!.isTemporary, isFalse);
      expect(data.action, Action.sendDm);
      expect(data.orderId, 'order-abc');
    });

    test('returns empty values map (no payload extraction)', () async {
      final message = MostroMessage(
        action: Action.sendDm,
        id: 'order-xyz',
      );

      final data = await NotificationDataExtractor.extractFromMostroMessage(
        message,
        null,
      );

      expect(data, isNotNull);
      expect(data!.values, isEmpty);
    });
  });

  group('NotificationDataExtractor for cooperativeCancelAccepted', () {
    test('produces non-temporary notification data', () async {
      final message = MostroMessage(
        action: Action.cooperativeCancelAccepted,
        id: 'order-cancel',
      );

      final data = await NotificationDataExtractor.extractFromMostroMessage(
        message,
        null,
      );

      expect(data, isNotNull);
      expect(data!.isTemporary, isFalse);
      expect(data.action, Action.cooperativeCancelAccepted);
    });
  });

  group('resolveNotificationRoute', () {
    test('navigates to notifications screen when payload is null', () {
      expect(resolveNotificationRoute(null), '/notifications');
    });

    test('navigates to notifications screen when payload is empty', () {
      expect(resolveNotificationRoute(''), '/notifications');
    });

    test('navigates to dispute chat when admin_dm has disputeId', () {
      final payload = jsonEncode({
        'type': 'admin_dm',
        'orderId': 'order-123',
        'disputeId': 'dispute-456',
      });
      expect(
        resolveNotificationRoute(payload),
        '/dispute_details/dispute-456',
      );
    });

    test('falls back to trade detail when admin_dm has no disputeId', () {
      final payload = jsonEncode({
        'type': 'admin_dm',
        'orderId': 'order-123',
      });
      expect(resolveNotificationRoute(payload), '/trade_detail/order-123');
    });

    test('routes to notifications when admin_dm has no orderId', () {
      final payload = jsonEncode({
        'type': 'admin_dm',
        'orderId': null,
      });
      expect(resolveNotificationRoute(payload), '/notifications');
    });

    test('treats plain string as legacy orderId payload', () {
      expect(
        resolveNotificationRoute('legacy-order-id'),
        '/trade_detail/legacy-order-id',
      );
    });

    test('routes to notifications when JSON is not an object', () {
      expect(resolveNotificationRoute('"just-a-string"'), '/notifications');
      expect(resolveNotificationRoute('[1,2,3]'), '/notifications');
    });

    test('routes to trade detail when unknown type has orderId', () {
      final payload = jsonEncode({
        'type': 'unknown_type',
        'orderId': 'order-789',
      });
      expect(resolveNotificationRoute(payload), '/trade_detail/order-789');
    });

    test('routes to notifications when unknown type has no orderId', () {
      final payload = jsonEncode({
        'type': 'unknown_type',
      });
      expect(resolveNotificationRoute(payload), '/notifications');
    });

    test('routes P2P chat notification (plain orderId) to trade detail', () {
      expect(
        resolveNotificationRoute('p2p-chat-order-id'),
        '/trade_detail/p2p-chat-order-id',
      );
    });
  });

  group('P2P chat notification uses chatMessage action', () {
    test('MostroMessage with chatMessage action preserves orderId', () {
      final message = MostroMessage(
        action: Action.chatMessage,
        id: 'order-p2p',
        timestamp: 1700000000000,
      );

      expect(message.action, Action.chatMessage);
      expect(message.id, 'order-p2p');
    });

    test('chatMessage action is distinct from sendDm', () {
      expect(Action.chatMessage, isNot(equals(Action.sendDm)));
      expect(Action.chatMessage.value, 'chat-message');
      expect(Action.sendDm.value, 'send-dm');
    });

    test('NotificationDataExtractor produces non-temporary data for chatMessage', () async {
      final message = MostroMessage(
        action: Action.chatMessage,
        id: 'order-p2p-123',
      );

      final data = await NotificationDataExtractor.extractFromMostroMessage(
        message,
        null,
      );

      expect(data, isNotNull);
      expect(data!.isTemporary, isFalse);
      expect(data.action, Action.chatMessage);
      expect(data.orderId, 'order-p2p-123');
    });

    test('chatMessage maps to generic message keys, not admin keys', () {
      final chatTitle = NotificationMessageMapper.getTitleKey(Action.chatMessage);
      final chatMessage = NotificationMessageMapper.getMessageKey(Action.chatMessage);
      final adminTitle = NotificationMessageMapper.getTitleKey(Action.sendDm);
      final adminMessage = NotificationMessageMapper.getMessageKey(Action.sendDm);

      expect(chatTitle, 'notification_new_message_title');
      expect(chatMessage, 'notification_new_message_message');
      expect(adminTitle, 'notification_admin_message_title');
      expect(adminMessage, 'notification_admin_message_message');
      expect(chatTitle, isNot(equals(adminTitle)));
      expect(chatMessage, isNot(equals(adminMessage)));
    });
  });
}
