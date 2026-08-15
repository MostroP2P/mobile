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
/// A pending replay is always honoured rather than capped. Capping it would
/// mean declaring a history hydrated while knowing a queued resolution may be
/// missing from it, which disables recovery for every later resolution too.
/// The chain is self-limiting instead: each replay needs a fresh rejection
/// arriving while the pass runs, and ends as soon as one pass sees none.
SyncCompletion resolveSyncCompletion({
  required bool succeeded,
  required bool resyncRequested,
}) {
  if (resyncRequested) return SyncCompletion.replay;
  return succeeded ? SyncCompletion.hydrated : SyncCompletion.unhydrated;
}
