import 'package:mostro_mobile/data/models/restore_response.dart';
import 'package:test/test.dart';

void main() {
  group('RestoredDispute - _normalizeInitiator', () {
    test('returns "buyer" for valid lowercase buyer', () {
      final dispute = RestoredDispute.fromJson({
        'dispute_id': 'dispute-123',
        'order_id': 'order-456',
        'trade_index': 0,
        'status': 'in-progress',
        'initiator': 'buyer',
      });

      expect(dispute.initiator, equals('buyer'));
    });

    test('returns "seller" for valid lowercase seller', () {
      final dispute = RestoredDispute.fromJson({
        'dispute_id': 'dispute-123',
        'order_id': 'order-456',
        'trade_index': 1,
        'status': 'in-progress',
        'initiator': 'seller',
      });

      expect(dispute.initiator, equals('seller'));
    });

    test('normalizes uppercase "BUYER" to lowercase "buyer"', () {
      final dispute = RestoredDispute.fromJson({
        'dispute_id': 'dispute-123',
        'order_id': 'order-456',
        'trade_index': 0,
        'status': 'in-progress',
        'initiator': 'BUYER',
      });

      expect(dispute.initiator, equals('buyer'));
    });

    test('normalizes uppercase "SELLER" to lowercase "seller"', () {
      final dispute = RestoredDispute.fromJson({
        'dispute_id': 'dispute-123',
        'order_id': 'order-456',
        'trade_index': 1,
        'status': 'in-progress',
        'initiator': 'SELLER',
      });

      expect(dispute.initiator, equals('seller'));
    });

    test('normalizes mixed case "BuYeR" to lowercase "buyer"', () {
      final dispute = RestoredDispute.fromJson({
        'dispute_id': 'dispute-123',
        'order_id': 'order-456',
        'trade_index': 0,
        'status': 'in-progress',
        'initiator': 'BuYeR',
      });

      expect(dispute.initiator, equals('buyer'));
    });

    test('trims whitespace from " buyer "', () {
      final dispute = RestoredDispute.fromJson({
        'dispute_id': 'dispute-123',
        'order_id': 'order-456',
        'trade_index': 0,
        'status': 'in-progress',
        'initiator': ' buyer ',
      });

      expect(dispute.initiator, equals('buyer'));
    });

    test('trims whitespace from "  seller  "', () {
      final dispute = RestoredDispute.fromJson({
        'dispute_id': 'dispute-123',
        'order_id': 'order-456',
        'trade_index': 1,
        'status': 'in-progress',
        'initiator': '  seller  ',
      });

      expect(dispute.initiator, equals('seller'));
    });

    test('returns null for invalid value "admin"', () {
      final dispute = RestoredDispute.fromJson({
        'dispute_id': 'dispute-123',
        'order_id': 'order-456',
        'trade_index': 0,
        'status': 'in-progress',
        'initiator': 'admin',
      });

      expect(dispute.initiator, isNull);
    });

    test('returns null for invalid value "unknown"', () {
      final dispute = RestoredDispute.fromJson({
        'dispute_id': 'dispute-123',
        'order_id': 'order-456',
        'trade_index': 0,
        'status': 'in-progress',
        'initiator': 'unknown',
      });

      expect(dispute.initiator, isNull);
    });

    test('returns null for empty string', () {
      final dispute = RestoredDispute.fromJson({
        'dispute_id': 'dispute-123',
        'order_id': 'order-456',
        'trade_index': 0,
        'status': 'in-progress',
        'initiator': '',
      });

      expect(dispute.initiator, isNull);
    });

    test('returns null for whitespace-only string', () {
      final dispute = RestoredDispute.fromJson({
        'dispute_id': 'dispute-123',
        'order_id': 'order-456',
        'trade_index': 0,
        'status': 'in-progress',
        'initiator': '   ',
      });

      expect(dispute.initiator, isNull);
    });

    test('returns null when initiator field is missing', () {
      final dispute = RestoredDispute.fromJson({
        'dispute_id': 'dispute-123',
        'order_id': 'order-456',
        'trade_index': 0,
        'status': 'in-progress',
      });

      expect(dispute.initiator, isNull);
    });

    test('returns null when initiator is explicitly null', () {
      final dispute = RestoredDispute.fromJson({
        'dispute_id': 'dispute-123',
        'order_id': 'order-456',
        'trade_index': 0,
        'status': 'in-progress',
        'initiator': null,
      });

      expect(dispute.initiator, isNull);
    });
  });

  group('RestoredDispute - toJson', () {
    test('includes initiator in JSON when present', () {
      final dispute = RestoredDispute(
        disputeId: 'dispute-123',
        orderId: 'order-456',
        tradeIndex: 0,
        status: 'in-progress',
        initiator: 'buyer',
      );

      final json = dispute.toJson();

      expect(json['initiator'], equals('buyer'));
    });

    test('excludes initiator from JSON when null', () {
      final dispute = RestoredDispute(
        disputeId: 'dispute-123',
        orderId: 'order-456',
        tradeIndex: 0,
        status: 'in-progress',
        initiator: null,
      );

      final json = dispute.toJson();

      expect(json.containsKey('initiator'), isFalse);
    });
  });
}
