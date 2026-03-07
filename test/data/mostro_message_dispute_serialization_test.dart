import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';

void main() {
  group('MostroMessage<Dispute> Serialization', () {
    test('should serialize and deserialize MostroMessage<Dispute> correctly', () {
      // Arrange
      final dispute = Dispute(
        disputeId: 'test-dispute-123',
        orderId: 'test-order-456',
        status: 'initiated',
        action: 'dispute-initiated-by-peer',
        createdAt: DateTime(2024, 1, 15, 10, 30),
      );

      final originalMessage = MostroMessage<Dispute>(
        id: 'test-order-456',
        action: Action.disputeInitiatedByPeer,
        payload: dispute,
        timestamp: 1705315800000, // 2024-01-15 10:30:00
      );

      // Act - Serialize
      final json = originalMessage.toJson();

      // Assert - Check JSON structure
      expect(json['id'], 'test-order-456');
      expect(json['action'], 'dispute-initiated-by-peer');
      expect(json['payload'], isNotNull);
      expect(json['payload']['dispute'], 'test-dispute-123');

      // Act - Deserialize without type parameter (simulating storage behavior)
      final deserializedMessage = MostroMessage.fromJson(json);

      // Assert - Check deserialized message
      expect(deserializedMessage.id, 'test-order-456');
      expect(deserializedMessage.action, Action.disputeInitiatedByPeer);
      expect(deserializedMessage.payload, isNotNull);
      expect(deserializedMessage.payload.runtimeType, Dispute);

      // Assert - Check getPayload<Dispute>() works
      final extractedDispute = deserializedMessage.getPayload<Dispute>();
      expect(extractedDispute, isNotNull);
      expect(extractedDispute!.disputeId, 'test-dispute-123');
      expect(extractedDispute.orderId, 'test-order-456');
      expect(extractedDispute.status, 'initiated');
      expect(extractedDispute.action, 'dispute-initiated-by-peer');
    });

    test('should handle MostroMessage<Dispute> in storage-like scenario', () {
      // Arrange - Simulate what happens during restore
      final dispute = Dispute(
        disputeId: 'dispute-789',
        orderId: 'order-123',
        status: 'initiated',
        action: 'dispute-initiated-by-you',
        createdAt: DateTime.now(),
      );

      final disputeMessage = MostroMessage<Dispute>(
        id: 'order-123',
        action: Action.disputeInitiatedByYou,
        payload: dispute,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      // Act - Simulate storage: toJson -> store -> retrieve -> fromJson
      final storedJson = disputeMessage.toJson();
      final retrievedMessage = MostroMessage.fromJson(storedJson);

      // Assert - Payload type is preserved
      expect(retrievedMessage.payload is Dispute, isTrue);

      // Assert - getPayload<Order>() returns null (not an Order)
      final orderPayload = retrievedMessage.getPayload<Order>();
      expect(orderPayload, isNull);

      // Assert - getPayload<Dispute>() returns the dispute
      final disputePayload = retrievedMessage.getPayload<Dispute>();
      expect(disputePayload, isNotNull);
      expect(disputePayload!.disputeId, 'dispute-789');
    });

    test('should correctly identify payload type after deserialization', () {
      // Arrange
      final dispute = Dispute(
        disputeId: 'test-id',
        orderId: 'order-id',
        status: 'in-progress',
        action: 'dispute-initiated-by-peer',
        createdAt: DateTime.now(),
      );

      final message = MostroMessage<Dispute>(
        id: 'order-id',
        action: Action.disputeInitiatedByPeer,
        payload: dispute,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      // Act
      final json = message.toJson();
      final deserialized = MostroMessage.fromJson(json);

      // Assert - Runtime type checks work correctly
      expect(deserialized.payload is Dispute, isTrue,
          reason: 'Payload should be Dispute type at runtime');
      expect(deserialized.payload is Order, isFalse,
          reason: 'Payload should not be Order type');

      // Assert - Generic getPayload method works correctly
      expect(deserialized.getPayload<Dispute>(), isNotNull,
          reason: 'getPayload<Dispute>() should return the dispute');
      expect(deserialized.getPayload<Order>(), isNull,
          reason: 'getPayload<Order>() should return null for Dispute payload');
    });

    test('should preserve dispute data through serialization cycle', () {
      // Arrange
      final originalDispute = Dispute(
        disputeId: 'dispute-uuid-123',
        orderId: 'order-uuid-456',
        status: 'resolved',
        action: 'admin-settled',
        createdAt: DateTime(2024, 3, 6, 15, 30),
      );

      final message = MostroMessage<Dispute>(
        id: 'order-uuid-456',
        action: Action.adminSettled,
        payload: originalDispute,
        timestamp: 1709738400000,
      );

      // Act
      final json = message.toJson();
      final restored = MostroMessage.fromJson(json);
      final restoredDispute = restored.getPayload<Dispute>();

      // Assert - All dispute fields preserved
      expect(restoredDispute, isNotNull);
      expect(restoredDispute!.disputeId, originalDispute.disputeId);
      expect(restoredDispute.orderId, originalDispute.orderId);
      expect(restoredDispute.status, originalDispute.status);
      expect(restoredDispute.action, originalDispute.action);
      expect(restoredDispute.createdAt, originalDispute.createdAt);
    });
  });
}
