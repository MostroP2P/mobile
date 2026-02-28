import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/restore_response.dart';

bool determineIfUserInitiatedDispute({
  required RestoredDispute? restoredDispute,
  required Role? userRole,
}) {
  return restoredDispute?.initiator != null && userRole != null
      ? userRole.initiatorValue == restoredDispute!.initiator
      : false;
}

void main() {
  group('RestoreManager - Dispute Initiator Matching Logic', () {
    test('returns true when buyer user initiated buyer dispute', () {
      final dispute = RestoredDispute(
        disputeId: 'dispute-123',
        orderId: 'order-456',
        tradeIndex: 0,
        status: 'in-progress',
        initiator: 'buyer',
      );

      final result = determineIfUserInitiatedDispute(
        restoredDispute: dispute,
        userRole: Role.buyer,
      );

      expect(result, isTrue);
    });

    test('returns true when seller user initiated seller dispute', () {
      final dispute = RestoredDispute(
        disputeId: 'dispute-123',
        orderId: 'order-456',
        tradeIndex: 1,
        status: 'in-progress',
        initiator: 'seller',
      );

      final result = determineIfUserInitiatedDispute(
        restoredDispute: dispute,
        userRole: Role.seller,
      );

      expect(result, isTrue);
    });

    test('returns false when buyer user did not initiate seller dispute', () {
      final dispute = RestoredDispute(
        disputeId: 'dispute-123',
        orderId: 'order-456',
        tradeIndex: 1,
        status: 'in-progress',
        initiator: 'seller',
      );

      final result = determineIfUserInitiatedDispute(
        restoredDispute: dispute,
        userRole: Role.buyer,
      );

      expect(result, isFalse);
    });

    test('returns false when seller user did not initiate buyer dispute', () {
      final dispute = RestoredDispute(
        disputeId: 'dispute-123',
        orderId: 'order-456',
        tradeIndex: 0,
        status: 'in-progress',
        initiator: 'buyer',
      );

      final result = determineIfUserInitiatedDispute(
        restoredDispute: dispute,
        userRole: Role.seller,
      );

      expect(result, isFalse);
    });

    test('returns false when initiator is null', () {
      final dispute = RestoredDispute(
        disputeId: 'dispute-123',
        orderId: 'order-456',
        tradeIndex: 0,
        status: 'in-progress',
        initiator: null,
      );

      final result = determineIfUserInitiatedDispute(
        restoredDispute: dispute,
        userRole: Role.buyer,
      );

      expect(result, isFalse);
    });

    test('returns false when userRole is null', () {
      final dispute = RestoredDispute(
        disputeId: 'dispute-123',
        orderId: 'order-456',
        tradeIndex: 0,
        status: 'in-progress',
        initiator: 'buyer',
      );

      final result = determineIfUserInitiatedDispute(
        restoredDispute: dispute,
        userRole: null,
      );

      expect(result, isFalse);
    });

    test('returns false when restoredDispute is null', () {
      final result = determineIfUserInitiatedDispute(
        restoredDispute: null,
        userRole: Role.buyer,
      );

      expect(result, isFalse);
    });

    test('returns false when both initiator and userRole are null', () {
      final dispute = RestoredDispute(
        disputeId: 'dispute-123',
        orderId: 'order-456',
        tradeIndex: 0,
        status: 'in-progress',
        initiator: null,
      );

      final result = determineIfUserInitiatedDispute(
        restoredDispute: dispute,
        userRole: null,
      );

      expect(result, isFalse);
    });

    test('uses type-safe initiatorValue from Role enum', () {
      final buyerDispute = RestoredDispute(
        disputeId: 'dispute-123',
        orderId: 'order-456',
        tradeIndex: 0,
        status: 'in-progress',
        initiator: 'buyer',
      );

      final sellerDispute = RestoredDispute(
        disputeId: 'dispute-456',
        orderId: 'order-789',
        tradeIndex: 1,
        status: 'in-progress',
        initiator: 'seller',
      );

      expect(Role.buyer.initiatorValue, equals('buyer'));
      expect(Role.seller.initiatorValue, equals('seller'));

      expect(
        determineIfUserInitiatedDispute(
          restoredDispute: buyerDispute,
          userRole: Role.buyer,
        ),
        isTrue,
      );

      expect(
        determineIfUserInitiatedDispute(
          restoredDispute: sellerDispute,
          userRole: Role.seller,
        ),
        isTrue,
      );
    });
  });
}
