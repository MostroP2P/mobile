/// Claims event ids for the duration of their processing.
///
/// Every path that consumes relay events deduplicates against a durable store,
/// but that store must only ever record events that have been authenticated —
/// an id is a relay's claim, not evidence, and writing one before the
/// signature is checked lets a forged copy take the slot and censor the
/// genuine event behind it.
///
/// Moving the durable write after authentication reopens a smaller window:
/// `hasItem` is asynchronous, so two relays delivering the same event can both
/// observe it as unseen and process it twice. This closes that window without
/// persisting anything, by claiming the id synchronously for the turn and
/// releasing it once processing ends — so a rejected event leaves no trace and
/// a genuine one arriving later is still handled.
class InFlightEvents {
  final Set<String> _ids = <String>{};

  /// Runs [action] unless [eventId] is already in flight, in which case this
  /// is a concurrent re-delivery and does nothing.
  ///
  /// The claim is released even if [action] throws, so a failure cannot leave
  /// an id permanently blocked.
  Future<void> guard(String eventId, Future<void> Function() action) async {
    if (!_ids.add(eventId)) return;
    try {
      await action();
    } finally {
      _ids.remove(eventId);
    }
  }

  /// Whether [eventId] is currently being processed. For tests and debugging.
  bool isInFlight(String eventId) => _ids.contains(eventId);
}
