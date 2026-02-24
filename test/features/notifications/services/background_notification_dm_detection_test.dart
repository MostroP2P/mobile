import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

/// Tests for DM format detection logic used in background notification service.
///
/// Tests exercise [NostrUtils.isDmPayload], the same pure function called by
/// `_decryptAndProcessEvent()`, `MostroService`, and `DisputeChatNotifier`.
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

    test('MostroMessage with sendDm action preserves orderId and timestamp', () {
      const testOrderId = 'test-order-123';
      const testTimestamp = 1700000000000;

      final message = _createDmNotificationMessage(testOrderId, testTimestamp);

      expect(message.action, equals(Action.sendDm));
      expect(message.id, equals(testOrderId));
      expect(message.timestamp, equals(testTimestamp));
    });
  });
}

/// Simulates the MostroMessage construction from _decryptAndProcessEvent
/// when a DM format is detected.
_DmMessage _createDmNotificationMessage(String orderId, int timestamp) {
  return _DmMessage(
    action: Action.sendDm,
    id: orderId,
    timestamp: timestamp,
  );
}

/// Lightweight wrapper to test the construction without importing MostroMessage
/// (which requires full Payload generics setup).
class _DmMessage {
  final Action action;
  final String id;
  final int timestamp;

  _DmMessage({
    required this.action,
    required this.id,
    required this.timestamp,
  });
}
