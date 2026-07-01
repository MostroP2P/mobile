import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Serializes session-mutating critical sections so they never interleave:
/// session creation plus the dependent publish (order create, take buy/sell)
/// and the restore session reset/rebuild. While one holder runs, no other
/// critical section can — eliminating the TOCTOU window where a freshly created
/// session could be wiped by a concurrent restore reset.
///
/// Single shared instance via [sessionLifecycleLockProvider]; every flow must
/// go through the same instance for the serialization to hold.
class SessionLifecycleLock {
  Future<void> _tail = Future.value();

  /// Acquires the lock, queued behind any current holder. Returns a release
  /// callback the caller MUST invoke in a `finally` block. Prefer
  /// [withSessionLock] for new call sites; use this only when an existing
  /// try/finally already guarantees release.
  Future<void Function()> acquire() async {
    final previous = _tail;
    final completer = Completer<void>();
    _tail = completer.future;
    await previous;
    return () => completer.complete();
  }

  /// Runs [action] inside the critical section, releasing automatically even if
  /// [action] throws. Do not call back into the lock from within [action] — it
  /// is not re-entrant and would deadlock.
  Future<T> withSessionLock<T>(Future<T> Function() action) async {
    final release = await acquire();
    try {
      return await action();
    } finally {
      release();
    }
  }
}

final sessionLifecycleLockProvider =
    Provider<SessionLifecycleLock>((ref) => SessionLifecycleLock());
