import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';

/// Tests for DM format detection logic used in background notification service.
///
/// The background service's `_decryptAndProcessEvent()` must distinguish between:
/// - Standard Mostro messages: [{"order": {"action": "...", ...}}]
/// - Admin/dispute DM messages: [{"dm": {"action": "send-dm", ...}}]
///
/// Since the actual method is a private top-level function that depends on
/// NostrEvent decryption and database access, we test the detection logic
/// and MostroMessage construction in isolation.
void main() {
  group('Admin DM format detection', () {
    test('detects dm wrapper key in decoded JSON', () {
      final dmPayload = jsonDecode(
        '[{"dm": {"action": "send-dm", "payload": {"text_message": "Hello"}}}]',
      );

      expect(dmPayload, isList);
      expect(dmPayload, isNotEmpty);

      final firstItem = dmPayload[0];
      expect(firstItem, isA<Map>());
      expect((firstItem as Map).containsKey('dm'), isTrue);
    });

    test('does not detect dm key in standard Mostro message', () {
      final orderPayload = jsonDecode(
        '[{"order": {"action": "new-order", "id": "abc123", "payload": null}}]',
      );

      final firstItem = orderPayload[0];
      expect(firstItem, isA<Map>());
      expect((firstItem as Map).containsKey('dm'), isFalse);
      expect((firstItem as Map).containsKey('order'), isTrue);
    });

    test('does not detect dm key in restore message', () {
      final restorePayload = jsonDecode(
        '[{"restore": {"action": "restore-session", "id": "abc123"}}]',
      );

      final firstItem = restorePayload[0];
      expect((firstItem as Map).containsKey('dm'), isFalse);
    });

    test('does not detect dm key in cant-do message', () {
      final cantDoPayload = jsonDecode(
        '[{"cant-do": {"action": "cant-do", "payload": null}}]',
      );

      final firstItem = cantDoPayload[0];
      expect((firstItem as Map).containsKey('dm'), isFalse);
    });

    test('MostroMessage with sendDm action preserves orderId and timestamp', () {
      const testOrderId = 'test-order-123';
      const testTimestamp = 1700000000000;

      // This mirrors what _decryptAndProcessEvent creates for DM detection
      final message = _createDmNotificationMessage(testOrderId, testTimestamp);

      expect(message.action, equals(Action.sendDm));
      expect(message.id, equals(testOrderId));
      expect(message.timestamp, equals(testTimestamp));
    });

    test('handles dm payload with minimal content', () {
      final dmPayload = jsonDecode('[{"dm": {}}]');

      final firstItem = dmPayload[0];
      expect((firstItem as Map).containsKey('dm'), isTrue);
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
