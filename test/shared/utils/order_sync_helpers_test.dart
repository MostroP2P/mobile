import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/shared/utils/order_sync_helpers.dart';

/// A `sync()` pass may only claim hydration when it actually read the history.
/// Claiming it after a failed read leaves an admin resolution that was rejected
/// during startup permanently dropped, since nothing triggers another replay.

SyncCompletion _resolve({
  required bool succeeded,
  bool resyncRequested = false,
}) =>
    resolveSyncCompletion(
      succeeded: succeeded,
      resyncRequested: resyncRequested,
    );

void main() {
  group('resolveSyncCompletion', () {
    test('a clean pass with nothing queued hydrates', () {
      expect(_resolve(succeeded: true), equals(SyncCompletion.hydrated));
    });

    test('a failed read does not hydrate', () {
      expect(_resolve(succeeded: false), equals(SyncCompletion.unhydrated),
          reason: 'recovery must stay available after a failed history read');
    });

    test('a queued replay defers hydration even on a successful pass', () {
      expect(_resolve(succeeded: true, resyncRequested: true),
          equals(SyncCompletion.replay),
          reason: 'the message that queued the replay is not in this pass');
    });

    test('a queued replay after a failed pass still replays', () {
      expect(_resolve(succeeded: false, resyncRequested: true),
          equals(SyncCompletion.replay));
    });

    test('a pending replay is never traded for hydration', () {
      // Declaring a history hydrated while a queued resolution may be missing
      // from it disables recovery for every later resolution as well.
      for (final succeeded in [true, false]) {
        expect(_resolve(succeeded: succeeded, resyncRequested: true),
            equals(SyncCompletion.replay),
            reason: 'a queued replay outranks the outcome of this pass');
      }
    });
  });
}
