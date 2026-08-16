import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/dispute_chat.dart';
import 'package:mostro_mobile/data/models/dispute_event.dart';

void main() {
  group('DisputeChat.fromJson', () {
    test('reads every field from a complete payload', () {
      // Arrange
      final json = <String, dynamic>{
        'id': 'chat-1',
        'message': 'hello admin',
        'timestamp': '2026-01-02T03:04:05.000Z',
        'isFromUser': true,
        'adminPubkey': 'a' * 64,
        'isPending': true,
        'error': 'send failed',
      };

      // Act
      final chat = DisputeChat.fromJson(json);

      // Assert
      expect(chat.id, 'chat-1');
      expect(chat.message, 'hello admin');
      expect(chat.timestamp, DateTime.parse('2026-01-02T03:04:05.000Z'));
      expect(chat.isFromUser, isTrue);
      expect(chat.adminPubkey, 'a' * 64);
      expect(chat.isPending, isTrue);
      expect(chat.error, 'send failed');
    });

    test('falls back to safe defaults for an empty payload', () {
      final before = DateTime.now().subtract(const Duration(seconds: 5));

      final chat = DisputeChat.fromJson(const <String, dynamic>{});

      expect(chat.id, '');
      expect(chat.message, '');
      expect(chat.isFromUser, isFalse);
      expect(chat.adminPubkey, isNull);
      expect(chat.isPending, isFalse);
      expect(chat.error, isNull);
      expect(chat.timestamp.isAfter(before), isTrue);
    });

    test('treats an integer timestamp below 1e12 as seconds', () {
      final chat = DisputeChat.fromJson(const {'timestamp': 1700000000});

      expect(chat.timestamp,
          DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000));
    });

    test('treats an integer timestamp at or above 1e12 as milliseconds', () {
      final chat = DisputeChat.fromJson(const {'timestamp': 1700000000000});

      expect(
          chat.timestamp, DateTime.fromMillisecondsSinceEpoch(1700000000000));
    });

    test('falls back to now for an unparseable string timestamp', () {
      final before = DateTime.now().subtract(const Duration(seconds: 5));

      final chat = DisputeChat.fromJson(const {'timestamp': 'not-a-date'});

      expect(chat.timestamp.isAfter(before), isTrue);
    });

    test('falls back to now for an empty string timestamp', () {
      final before = DateTime.now().subtract(const Duration(seconds: 5));

      final chat = DisputeChat.fromJson(const {'timestamp': ''});

      expect(chat.timestamp.isAfter(before), isTrue);
    });

    test('falls back to now for a timestamp of an unsupported type', () {
      final before = DateTime.now().subtract(const Duration(seconds: 5));

      final chat = DisputeChat.fromJson(const {'timestamp': 12.5});

      expect(chat.timestamp.isAfter(before), isTrue);
    });
  });

  group('DisputeChat.toJson', () {
    test('serialises the timestamp as ISO-8601 and survives a round trip', () {
      final original = DisputeChat(
        id: 'chat-2',
        message: 'ping',
        timestamp: DateTime.utc(2026, 5, 6, 7, 8, 9),
        isFromUser: false,
        adminPubkey: 'b' * 64,
        isPending: false,
        error: null,
      );

      final json = original.toJson();
      final restored = DisputeChat.fromJson(json);

      expect(json['timestamp'], '2026-05-06T07:08:09.000Z');
      expect(restored.id, original.id);
      expect(restored.message, original.message);
      expect(restored.timestamp, original.timestamp);
      expect(restored.isFromUser, original.isFromUser);
      expect(restored.adminPubkey, original.adminPubkey);
      expect(restored.isPending, original.isPending);
      expect(restored.error, original.error);
    });
  });

  group('DisputeChat.copyWith', () {
    DisputeChat base() => DisputeChat(
          id: 'chat-3',
          message: 'original',
          timestamp: DateTime.utc(2026, 1, 1),
          isFromUser: true,
          adminPubkey: 'c' * 64,
          isPending: true,
          error: 'boom',
        );

    test('returns an equivalent copy when no override is given', () {
      final original = base();

      final copy = original.copyWith();

      expect(copy, isNot(same(original)));
      expect(copy.toJson(), original.toJson());
    });

    test('overrides only the requested fields', () {
      final original = base();

      final copy = original.copyWith(message: 'edited', isPending: false);

      expect(copy.message, 'edited');
      expect(copy.isPending, isFalse);
      expect(copy.id, original.id);
      expect(copy.timestamp, original.timestamp);
      expect(copy.isFromUser, original.isFromUser);
      expect(copy.adminPubkey, original.adminPubkey);
      expect(copy.error, original.error);
    });

    test('overrides every field when all are provided', () {
      final copy = base().copyWith(
        id: 'other',
        message: 'other message',
        timestamp: DateTime.utc(2030),
        isFromUser: false,
        adminPubkey: 'd' * 64,
        isPending: false,
        error: 'other error',
      );

      expect(copy.id, 'other');
      expect(copy.message, 'other message');
      expect(copy.timestamp, DateTime.utc(2030));
      expect(copy.isFromUser, isFalse);
      expect(copy.adminPubkey, 'd' * 64);
      expect(copy.isPending, isFalse);
      expect(copy.error, 'other error');
    });

    test('uses defaults for the optional constructor arguments', () {
      final chat = DisputeChat(
        id: 'chat-4',
        message: 'minimal',
        timestamp: DateTime.utc(2026),
        isFromUser: true,
      );

      expect(chat.adminPubkey, isNull);
      expect(chat.isPending, isFalse);
      expect(chat.error, isNull);
    });
  });

  group('DisputeEvent.fromJson', () {
    test('reads every field from a complete payload', () {
      final event = DisputeEvent.fromJson(const {
        'id': 'evt-1',
        'disputeId': 'dispute-1',
        'orderId': 'order-1',
        'status': 'initiated',
        'createdAt': 1700000000000,
      });

      expect(event.id, 'evt-1');
      expect(event.disputeId, 'dispute-1');
      expect(event.orderId, 'order-1');
      expect(event.status, 'initiated');
      expect(event.createdAt, 1700000000000);
    });

    test('falls back to safe defaults for an empty payload', () {
      final before = DateTime.now()
          .subtract(const Duration(seconds: 5))
          .millisecondsSinceEpoch;

      final event = DisputeEvent.fromJson(const <String, dynamic>{});

      expect(event.id, '');
      expect(event.disputeId, '');
      expect(event.orderId, '');
      expect(event.status, 'unknown');
      expect(event.createdAt, greaterThan(before));
    });

    test('promotes a seconds-based createdAt to milliseconds', () {
      final event = DisputeEvent.fromJson(const {'createdAt': 1700000000});

      expect(event.createdAt, 1700000000 * 1000);
    });

    test('keeps a millisecond-based createdAt untouched', () {
      final event = DisputeEvent.fromJson(const {'createdAt': 1700000000000});

      expect(event.createdAt, 1700000000000);
    });

    test('parses an ISO-8601 string createdAt', () {
      final event =
          DisputeEvent.fromJson(const {'createdAt': '2026-01-02T03:04:05Z'});

      expect(
        event.createdAt,
        DateTime.parse('2026-01-02T03:04:05Z').millisecondsSinceEpoch,
      );
    });

    test('falls back to now for an unparseable string createdAt', () {
      final before = DateTime.now()
          .subtract(const Duration(seconds: 5))
          .millisecondsSinceEpoch;

      final event = DisputeEvent.fromJson(const {'createdAt': 'garbage'});

      expect(event.createdAt, greaterThan(before));
    });

    test('falls back to now for a createdAt of an unsupported type', () {
      final before = DateTime.now()
          .subtract(const Duration(seconds: 5))
          .millisecondsSinceEpoch;

      final event = DisputeEvent.fromJson(const {'createdAt': 1.5});

      expect(event.createdAt, greaterThan(before));
    });
  });

  group('DisputeEvent.toJson', () {
    test('survives a JSON round trip', () {
      final original = DisputeEvent(
        id: 'evt-2',
        disputeId: 'dispute-2',
        orderId: 'order-2',
        status: 'in-progress',
        createdAt: 1700000000000,
      );

      final restored = DisputeEvent.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.disputeId, original.disputeId);
      expect(restored.orderId, original.orderId);
      expect(restored.status, original.status);
      expect(restored.createdAt, original.createdAt);
    });
  });
}
