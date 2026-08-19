import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';

void main() {
  // One unit, milliseconds, normalised where the value enters the model.
  // Getting this wrong is not cosmetic: dispute ordering reads createdAt, so a
  // corrupted value pins a dispute to the top of the list permanently.
  group('MostroMessage.timestamp normalisation', () {
    final millis = DateTime(2026, 3, 1).millisecondsSinceEpoch;
    final seconds = millis ~/ 1000;

    Map<String, dynamic> payload(dynamic timestamp) => {
          'timestamp': timestamp,
          'action': 'fiat-sent-ok',
          'id': 'order-1',
        };

    test('a millisecond value from the local store is kept as-is', () {
      expect(MostroMessage.fromJson(payload(millis)).timestamp, millis);
    });

    test('a second value from the wire is scaled to milliseconds', () {
      expect(MostroMessage.fromJson(payload(seconds)).timestamp, millis);
    });

    test('an absent timestamp stays null', () {
      expect(MostroMessage.fromJson(payload(null)).timestamp, isNull);
    });

    test('a non-numeric timestamp is dropped rather than throwing', () {
      expect(MostroMessage.fromJson(payload('yesterday')).timestamp, isNull);
    });

    test('both representations of one instant agree', () {
      expect(
        MostroMessage.fromJson(payload(seconds)).timestamp,
        MostroMessage.fromJson(payload(millis)).timestamp,
      );
    });
  });

  group('dispute createdAt derived from a message timestamp', () {
    test('lands on the instant the message carries', () {
      final at = DateTime(2026, 3, 1);
      final state = OrderState(
        status: Status.dispute,
        action: Action.disputeInitiatedByPeer,
        order: null,
        dispute: Dispute(disputeId: 'd-1', orderId: 'order-1'),
      );

      final updated = state.updateWith(
        MostroMessage<Dispute>(
          id: 'order-1',
          action: Action.disputeInitiatedByPeer,
          payload: Dispute(disputeId: 'd-1', orderId: 'order-1'),
          timestamp: at.millisecondsSinceEpoch,
        ),
      );

      expect(updated.dispute!.createdAt, at);
    });

    // The regression MM-036 describes: multiplying an already-millisecond
    // value by 1000 dated disputes tens of thousands of years out.
    test('does not land in the far future', () {
      final state = OrderState(
        status: Status.dispute,
        action: Action.disputeInitiatedByPeer,
        order: null,
        dispute: Dispute(disputeId: 'd-1', orderId: 'order-1'),
      );

      final updated = state.updateWith(
        MostroMessage<Dispute>(
          id: 'order-1',
          action: Action.disputeInitiatedByPeer,
          payload: Dispute(disputeId: 'd-1', orderId: 'order-1'),
          timestamp: DateTime(2026, 3, 1).millisecondsSinceEpoch,
        ),
      );

      expect(updated.dispute!.createdAt!.year, lessThan(2100));
    });
  });
}
