import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/shared/utils/order_sync_helpers.dart';

/// A `sync()` pass may only claim hydration when it actually read the history.
/// Claiming it after a failed read leaves an admin resolution that was rejected
/// during startup permanently dropped, since nothing triggers another replay.

const _maxChained = 3;

SyncCompletion _resolve({
  required bool succeeded,
  bool resyncRequested = false,
  int resyncAttempts = 0,
}) =>
    resolveSyncCompletion(
      succeeded: succeeded,
      resyncRequested: resyncRequested,
      resyncAttempts: resyncAttempts,
      maxChainedResyncs: _maxChained,
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

    test('replays are bounded', () {
      expect(
          _resolve(
              succeeded: true,
              resyncRequested: true,
              resyncAttempts: _maxChained),
          equals(SyncCompletion.hydrated),
          reason: 'a successful pass hydrates once the budget is spent');

      expect(
          _resolve(
              succeeded: false,
              resyncRequested: true,
              resyncAttempts: _maxChained),
          equals(SyncCompletion.unhydrated),
          reason: 'an exhausted budget must not hydrate on a failed read');
    });

    test('the last chained attempt still replays', () {
      expect(
          _resolve(
              succeeded: true,
              resyncRequested: true,
              resyncAttempts: _maxChained - 1),
          equals(SyncCompletion.replay));
    });
  });
}
