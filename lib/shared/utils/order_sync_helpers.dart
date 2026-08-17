/// How a finished `sync()` pass should end.
enum SyncCompletion {
  /// Another pass was requested while this one ran: replay the history again.
  replay,

  /// The history was read successfully and nothing is queued behind it.
  hydrated,

  /// The read failed, or the replay budget ran out before one succeeded.
  /// Recovery stays available.
  unhydrated,
}

/// Decides how a `sync()` pass ends.
///
/// Hydration is only claimed by a pass that actually read the history with
/// nothing queued behind it. A failed read or a pending replay must leave
/// recovery available, otherwise an admin resolution rejected during startup
/// — before its dispute was loaded — is never revisited.
///
/// `maxChainedResyncs` bounds how many replays may be chained. Exhausting it
/// yields [SyncCompletion.unhydrated]: the pass neither claims a history it
/// knows may be missing the queued resolution, nor schedules yet another full
/// read. Recovery stays available because the notifier is still unhydrated, so
/// a later rejection can ask for a fresh pass — one read per message, rather
/// than a replay loop that rejected messages alone could keep running.
SyncCompletion resolveSyncCompletion({
  required bool succeeded,
  required bool resyncRequested,
  required int resyncAttempts,
  required int maxChainedResyncs,
}) {
  if (resyncRequested) {
    return resyncAttempts < maxChainedResyncs
        ? SyncCompletion.replay
        : SyncCompletion.unhydrated;
  }
  return succeeded ? SyncCompletion.hydrated : SyncCompletion.unhydrated;
}
