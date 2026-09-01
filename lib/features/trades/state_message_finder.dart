import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';

/// Finds the message that triggered a given order [Status], for the
/// trade-detail countdown.
///
/// The countdown rebuilds once per second, so the copy+sort below used to run
/// every tick. Results are memoized per history-list *instance*: the storage
/// index emits a new list only on real changes, so ticks hit the memo and new
/// messages recompute. The [Expando] keys are weak, so entries are collected
/// with the list and nothing leaks.
///
/// A result is only memoized when it does not depend on the current time: if
/// the future-timestamp guard skipped any message, the lookup is left uncached
/// so a later tick re-evaluates it once the clock catches up.
class StateMessageFinder {
  StateMessageFinder._();

  /// Messages timestamped further ahead than this are treated as bogus and
  /// skipped, rather than driving a countdown from a nonsense start time.
  static const futureTimestampTolerance = Duration(hours: 1);

  static final Expando<Map<Status, MostroMessage?>> _memo = Expando();

  /// Returns the newest valid message that produced [status], or null.
  static MostroMessage? findMessageForState(
    List<MostroMessage> messages,
    Status status, {
    DateTime? now,
  }) {
    final memo = _memo[messages] ??= {};
    if (memo.containsKey(status)) return memo[status];

    final result = _lookup(messages, status, now ?? DateTime.now());
    if (!result.skippedFutureMessage) {
      memo[status] = result.message;
    }
    return result.message;
  }

  static _LookupResult _lookup(
    List<MostroMessage> messages,
    Status status,
    DateTime now,
  ) {
    // Filter out messages with invalid timestamps
    final validMessages =
        messages.where((m) => m.timestamp != null && m.timestamp! > 0).toList();

    if (validMessages.isEmpty) {
      return const _LookupResult(null, skippedFutureMessage: false);
    }

    // Sort messages by timestamp (newest first)
    final sortedMessages = List<MostroMessage>.from(validMessages)
      ..sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));

    final cutoff = now.add(futureTimestampTolerance);
    var skippedFutureMessage = false;

    // Find the message that caused this state
    for (final message in sortedMessages) {
      // Additional validation: ensure timestamp is not in the future
      final messageTime =
          DateTime.fromMillisecondsSinceEpoch(message.timestamp!);
      if (messageTime.isAfter(cutoff)) {
        skippedFutureMessage = true;
        continue; // Skip messages with future timestamps
      }

      if (status == Status.waitingBuyerInvoice &&
          (message.action == actions.Action.addInvoice ||
              message.action == actions.Action.waitingBuyerInvoice)) {
        return _LookupResult(message,
            skippedFutureMessage: skippedFutureMessage);
      } else if (status == Status.waitingPayment &&
          (message.action == actions.Action.payInvoice ||
              message.action == actions.Action.waitingSellerToPay)) {
        return _LookupResult(message,
            skippedFutureMessage: skippedFutureMessage);
      }
    }
    return _LookupResult(null, skippedFutureMessage: skippedFutureMessage);
  }
}

class _LookupResult {
  const _LookupResult(this.message, {required this.skippedFutureMessage});

  final MostroMessage? message;

  /// True when the future-timestamp guard discarded a candidate, which makes
  /// this result time-dependent and therefore not safe to memoize.
  final bool skippedFutureMessage;
}
