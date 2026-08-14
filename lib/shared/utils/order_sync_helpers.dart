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
/// `maxChainedResyncs` bounds the replay chain so a stream of rejected
/// resolutions cannot keep queueing full history reads.
SyncCompletion resolveSyncCompletion({
  required bool succeeded,
  required bool resyncRequested,
  required int resyncAttempts,
  required int maxChainedResyncs,
}) {
  if (resyncRequested && resyncAttempts < maxChainedResyncs) {
    return SyncCompletion.replay;
  }
  return succeeded ? SyncCompletion.hydrated : SyncCompletion.unhydrated;
}
