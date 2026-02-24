import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/features/notifications/utils/notification_data_extractor.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

/// Tests for the admin/dispute DM background notification pipeline (Phase 1).
///
/// Validates three layers:
/// 1. [NostrUtils.isDmPayload] — pure detection of the `{"dm": ...}` envelope
/// 2. [MostroMessage] construction — synthetic message with [Action.sendDm]
/// 3. [NotificationDataExtractor] — ensures sendDm is NOT marked temporary
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

    test('handles dm payload with minimal content', () {
      final dmPayload = jsonDecode('[{"dm": {}}]');

      expect(NostrUtils.isDmPayload(dmPayload[0]), isTrue);
    });

    test('returns false for non-Map types', () {
      expect(NostrUtils.isDmPayload('string'), isFalse);
      expect(NostrUtils.isDmPayload(42), isFalse);
      expect(NostrUtils.isDmPayload(null), isFalse);
      expect(NostrUtils.isDmPayload([]), isFalse);
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
}
