import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/features/trades/state_message_finder.dart';

MostroMessage msg(actions.Action action, DateTime at) =>
    MostroMessage(action: action, timestamp: at.millisecondsSinceEpoch);

void main() {
  group('StateMessageFinder.findMessageForState', () {
    test('returns the newest message that produced the status', () {
      // Arrange
      final now = DateTime.utc(2026, 1, 1, 12);
      final older = msg(actions.Action.addInvoice,
          now.subtract(const Duration(minutes: 30)));
      final newer = msg(actions.Action.waitingBuyerInvoice,
          now.subtract(const Duration(minutes: 5)));
      final messages = [older, newer];

      // Act
      final found = StateMessageFinder.findMessageForState(
          messages, Status.waitingBuyerInvoice,
          now: now);

      // Assert
      expect(found, same(newer));
    });

    test('returns null when no message matches the status', () {
      // Arrange
      final now = DateTime.utc(2026, 1, 1, 12);
      final messages = [
        msg(actions.Action.addInvoice, now.subtract(const Duration(minutes: 5)))
      ];

      // Act
      final found = StateMessageFinder.findMessageForState(
          messages, Status.waitingPayment,
          now: now);

      // Assert
      expect(found, isNull);
    });

    test('ignores messages with missing or non-positive timestamps', () {
      // Arrange
      final now = DateTime.utc(2026, 1, 1, 12);
      final valid = msg(actions.Action.payInvoice,
          now.subtract(const Duration(minutes: 5)));
      final messages = [
        MostroMessage(action: actions.Action.payInvoice, timestamp: null),
        MostroMessage(action: actions.Action.payInvoice, timestamp: 0),
        valid,
      ];

      // Act
      final found = StateMessageFinder.findMessageForState(
          messages, Status.waitingPayment,
          now: now);

      // Assert
      expect(found, same(valid));
    });

    test('memoizes per list instance so 1 s ticks skip the sort', () {
      // Arrange
      final now = DateTime.utc(2026, 1, 1, 12);
      final expected = msg(actions.Action.addInvoice,
          now.subtract(const Duration(minutes: 5)));
      final messages = [expected];

      // Act
      final first = StateMessageFinder.findMessageForState(
          messages, Status.waitingBuyerInvoice,
          now: now);
      // Mutating the same instance must not be observed: a real change emits a
      // new list instance from the storage index.
      messages.clear();
      final second = StateMessageFinder.findMessageForState(
          messages, Status.waitingBuyerInvoice,
          now: now);

      // Assert
      expect(first, same(expected));
      expect(second, same(expected));
    });

    test('a new list instance recomputes', () {
      // Arrange
      final now = DateTime.utc(2026, 1, 1, 12);
      final first = msg(actions.Action.addInvoice,
          now.subtract(const Duration(minutes: 5)));
      final second = msg(actions.Action.waitingBuyerInvoice,
          now.subtract(const Duration(minutes: 1)));

      // Act
      final a = StateMessageFinder.findMessageForState(
          [first], Status.waitingBuyerInvoice,
          now: now);
      final b = StateMessageFinder.findMessageForState(
          [first, second], Status.waitingBuyerInvoice,
          now: now);

      // Assert
      expect(a, same(first));
      expect(b, same(second));
    });

    test('skips messages timestamped far in the future', () {
      // Arrange
      final now = DateTime.utc(2026, 1, 1, 12);
      final future =
          msg(actions.Action.addInvoice, now.add(const Duration(hours: 2)));
      final past = msg(actions.Action.addInvoice,
          now.subtract(const Duration(minutes: 5)));

      // Act
      final found = StateMessageFinder.findMessageForState(
          [future, past], Status.waitingBuyerInvoice,
          now: now);

      // Assert
      expect(found, same(past));
    });

    test('does not memoize a result the future guard made time-dependent', () {
      // A skipped future message must be re-evaluated once the clock catches
      // up, instead of being frozen for the lifetime of the list instance.
      // Arrange
      final now = DateTime.utc(2026, 1, 1, 12);
      final future =
          msg(actions.Action.addInvoice, now.add(const Duration(hours: 2)));
      final messages = [future];

      // Act
      final beforeClockCatchesUp = StateMessageFinder.findMessageForState(
          messages, Status.waitingBuyerInvoice,
          now: now);
      final afterClockCatchesUp = StateMessageFinder.findMessageForState(
          messages, Status.waitingBuyerInvoice,
          now: now.add(const Duration(hours: 3)));

      // Assert
      expect(beforeClockCatchesUp, isNull);
      expect(afterClockCatchesUp, same(future));
    });
  });
}
