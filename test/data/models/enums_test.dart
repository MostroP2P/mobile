import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models/enums/notification_type.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_type.dart';

void main() {
  group('Action', () {
    test('round-trips every value through fromString/toString', () {
      for (final action in Action.values) {
        expect(Action.fromString(action.value), action);
        expect(action.toString(), action.value);
      }
    });

    test('maps known protocol wire values', () {
      expect(Action.fromString('new-order'), Action.newOrder);
      expect(Action.fromString('take-sell'), Action.takeSell);
      expect(Action.fromString('hold-invoice-payment-settled'),
          Action.holdInvoicePaymentSettled);
      expect(Action.fromString('restore-session'), Action.restore);
    });

    test('throws ArgumentError for an unknown value', () {
      expect(() => Action.fromString('not-an-action'), throwsArgumentError);
      expect(() => Action.fromString(''), throwsArgumentError);
    });

    test('uses kebab-case wire values without underscores', () {
      for (final action in Action.values) {
        expect(action.value, isNot(contains('_')));
      }
    });
  });

  group('Status', () {
    test('round-trips every value through fromString/toString', () {
      for (final status in Status.values) {
        expect(Status.fromString(status.value), status);
        expect(status.toString(), status.value);
      }
    });

    test('throws ArgumentError for an unknown value', () {
      expect(() => Status.fromString('nope'), throwsArgumentError);
    });

    test('marks settled and closed statuses as terminal', () {
      const terminal = [
        Status.success,
        Status.canceled,
        Status.canceledByAdmin,
        Status.settledByAdmin,
        Status.completedByAdmin,
        Status.cooperativelyCanceled,
        Status.expired,
        Status.settledHoldInvoice,
      ];

      for (final status in terminal) {
        expect(status.isTerminal, isTrue, reason: '$status should be terminal');
      }
    });

    test('marks in-flight statuses as non-terminal', () {
      const live = [
        Status.active,
        Status.dispute,
        Status.fiatSent,
        Status.pending,
        Status.waitingBuyerInvoice,
        Status.waitingPayment,
        Status.waitingTakerBond,
        Status.paymentFailed,
        Status.inProgress,
      ];

      for (final status in live) {
        expect(status.isTerminal, isFalse,
            reason: '$status should not be terminal');
      }
    });

    test('partitions every enum value into terminal or live', () {
      final terminalCount = Status.values.where((s) => s.isTerminal).length;
      final liveCount = Status.values.where((s) => !s.isTerminal).length;

      expect(terminalCount + liveCount, Status.values.length);
    });

    test('isPayoutInvoice covers exactly the settled statuses', () {
      expect(Status.settledHoldInvoice.isPayoutInvoice, isTrue);
      expect(Status.paymentFailed.isPayoutInvoice, isTrue);

      for (final status in Status.values.where(
          (s) => s != Status.settledHoldInvoice && s != Status.paymentFailed)) {
        expect(status.isPayoutInvoice, isFalse,
            reason: '$status is not a payout invoice');
      }
    });
  });

  group('Role', () {
    test('round-trips every value through fromString/toString', () {
      for (final role in Role.values) {
        expect(Role.fromString(role.value), role);
        expect(role.toString(), role.value);
      }
    });

    test('exposes the wire value as the initiator value', () {
      expect(Role.buyer.initiatorValue, 'buyer');
      expect(Role.seller.initiatorValue, 'seller');
      expect(Role.admin.initiatorValue, 'admin');
    });

    test('throws ArgumentError for an unknown value', () {
      expect(() => Role.fromString('moderator'), throwsArgumentError);
    });
  });

  group('OrderType', () {
    test('maps buy and sell', () {
      expect(OrderType.fromString('buy'), OrderType.buy);
      expect(OrderType.fromString('sell'), OrderType.sell);
    });

    test('exposes the wire value', () {
      expect(OrderType.buy.value, 'buy');
      expect(OrderType.sell.value, 'sell');
    });

    test('throws ArgumentError for an unknown value', () {
      expect(() => OrderType.fromString('swap'), throwsArgumentError);
    });
  });

  group('CantDoReason', () {
    test('round-trips every value through fromString/toString', () {
      for (final reason in CantDoReason.values) {
        expect(CantDoReason.fromString(reason.value), reason);
        expect(reason.toString(), reason.value);
      }
    });

    test('maps known protocol wire values', () {
      expect(CantDoReason.fromString('invalid_signature'),
          CantDoReason.invalidSignature);
      expect(CantDoReason.fromString('out_of_range_fiat_amount'),
          CantDoReason.outOfRangeFiatAmount);
      expect(CantDoReason.fromString('too_many_requests'),
          CantDoReason.tooManyRequests);
    });

    test('throws ArgumentError for an unknown value', () {
      expect(() => CantDoReason.fromString('whatever'), throwsArgumentError);
    });

    test('uses snake_case wire values without dashes', () {
      for (final reason in CantDoReason.values) {
        expect(reason.value, isNot(contains('-')));
      }
    });
  });

  group('NotificationType', () {
    test('exposes the expected set of categories', () {
      expect(
        NotificationType.values,
        containsAll([
          NotificationType.orderUpdate,
          NotificationType.tradeUpdate,
          NotificationType.payment,
          NotificationType.dispute,
          NotificationType.cancellation,
          NotificationType.message,
          NotificationType.system,
        ]),
      );
      expect(NotificationType.values, hasLength(7));
    });

    test('keeps a stable declaration order', () {
      expect(NotificationType.orderUpdate.index, 0);
      expect(NotificationType.system.index, NotificationType.values.length - 1);
    });
  });

  group('SubscriptionType', () {
    test('exposes the expected subscription channels', () {
      expect(
        SubscriptionType.values,
        containsAll([
          SubscriptionType.chat,
          SubscriptionType.orders,
          SubscriptionType.disputeChat,
          SubscriptionType.relayList,
        ]),
      );
      expect(SubscriptionType.values, hasLength(4));
    });

    test('resolves values by name', () {
      expect(SubscriptionType.values.byName('chat'), SubscriptionType.chat);
      expect(SubscriptionType.values.byName('relayList'),
          SubscriptionType.relayList);
    });
  });
}
