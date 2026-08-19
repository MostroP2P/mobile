import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/shared/utils/in_flight_events.dart';

void main() {
  late InFlightEvents inFlight;

  setUp(() => inFlight = InFlightEvents());

  test('runs the action for an id that is not in flight', () async {
    var ran = 0;
    await inFlight.guard('a', () async => ran++);

    expect(ran, 1);
  });

  // The window this exists to close: two relays deliver the same event, both
  // start processing before either has written anything durable.
  test('a concurrent claim on the same id does not run twice', () async {
    var ran = 0;
    final gate = Completer<void>();

    final first = inFlight.guard('a', () async {
      ran++;
      await gate.future;
    });
    final second = inFlight.guard('a', () async => ran++);

    await second;
    expect(ran, 1, reason: 'the second delivery must be dropped');

    gate.complete();
    await first;
    expect(ran, 1);
  });

  test('the claim is released once processing ends', () async {
    await inFlight.guard('a', () async {});

    expect(inFlight.isInFlight('a'), isFalse);

    var ran = 0;
    await inFlight.guard('a', () async => ran++);
    expect(ran, 1, reason: 'a later delivery of the same id still runs');
  });

  // A rejected event must leave no trace, or one failure would block that id
  // for the lifetime of the process — a censorship primitive of its own.
  test('the claim is released when the action throws', () async {
    await expectLater(
      inFlight.guard('a', () async => throw StateError('rejected')),
      throwsStateError,
    );

    expect(inFlight.isInFlight('a'), isFalse);

    var ran = 0;
    await inFlight.guard('a', () async => ran++);
    expect(ran, 1);
  });

  test('distinct ids do not block each other', () async {
    final ran = <String>[];
    final gate = Completer<void>();

    final first = inFlight.guard('a', () async {
      ran.add('a');
      await gate.future;
    });
    await inFlight.guard('b', () async => ran.add('b'));

    expect(ran, ['a', 'b']);
    gate.complete();
    await first;
  });
}
