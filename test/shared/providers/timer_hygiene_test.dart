import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/shared/providers/time_provider.dart';

/// `countdownTimeProvider` drives the per-second countdown on the trade
/// detail and take-order screens. As a keep-alive provider, its 1 s
/// `Timer.periodic` ran for the rest of the app's life after the first visit
/// to either screen; autoDispose tears the stream (and its `onCancel` timer
/// cleanup) down when the last screen stops watching.
void main() {
  test('countdownTimeProvider is autoDispose', () {
    expect(
      countdownTimeProvider,
      isA<AutoDisposeStreamProvider<DateTime>>(),
      reason: 'a keep-alive countdown keeps its 1 s timer running forever '
          'after the first trade-detail visit',
    );
  });

  test('countdownTimeProvider is torn down when the last screen stops watching',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final sub = container.listen(countdownTimeProvider, (_, __) {});
    expect(container.exists(countdownTimeProvider), isTrue,
        reason: 'precondition: a watching screen keeps the ticker alive');

    // Leaving the screen: the stream — and with it the 1 s Timer.periodic
    // its onCancel/onDispose hooks clean up — must not outlive the listener.
    sub.close();
    await Future<void>.delayed(Duration.zero);

    expect(container.exists(countdownTimeProvider), isFalse);
  });

  test('timeProvider (30 s ticker) stays keep-alive for the list screens',
      () {
    // Documented status quo: the coarse ticker is shared by Home/Trades rows
    // and is cheap; scoping it further is plan item 2.7.
    expect(timeProvider, isNot(isA<AutoDisposeStreamProvider<DateTime>>()));
  });
}
