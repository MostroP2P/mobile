/// Largest Unix time, in seconds, that [DateTime] can hold (year 275760).
const int _maxSince = 8640000000000;

/// Reads the protocol's `since`: the Unix time, in seconds, of a user's first
/// trade, truncated to the start of its UTC day. Anything other than a
/// positive integer that [DateTime] can hold reads as absent.
int? parseReputationSince(Object? value) =>
    value is int && value > 0 && value <= _maxSince ? value : null;

/// Days a user has been on Mostro, computed when it is shown.
///
/// Counts from [since] when the daemon sent it. Daemons that predate it only
/// send a count computed when they published, the deprecated `days` /
/// `operating_days`, which goes stale on events that sit on relays;
/// [fallbackDays] carries that count. A [since] in the future, from a skewed
/// clock, gives 0.
int reputationDaysOnMostro({
  required int? since,
  required int fallbackDays,
  DateTime? now,
}) {
  if (since == null) return fallbackDays;
  final firstDay =
      DateTime.fromMillisecondsSinceEpoch(since * 1000, isUtc: true);
  final days = (now ?? DateTime.now()).difference(firstDay).inDays;
  return days < 0 ? 0 : days;
}
