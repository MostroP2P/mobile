import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/features/order/notifiers/abstract_mostro_notifier.dart';

/// Regression for the maker-bond abandon review concern: the create-order
/// timeout must be fully torn down before the abandon path can run.
///
/// `_handleMakerBondInvoice` cancels the timer (via
/// `cancelSessionTimeoutCleanupForRequestId`) in the same step that sets
/// `bondPending = true` and navigates to the pay-bond screen — which is the
/// only place the abandon (`cancelOrder` with `bondPending`) is reachable from.
/// These tests guard the mechanism it relies on: cancelling actually disarms
/// the timer, so no stale timer can outlive a torn-down maker-bond flow.
void main() {
  late ProviderContainer container;
  late Ref ref;

  setUp(() {
    container = ProviderContainer();
    // The static timer only dereferences `ref` when it fires (after 10s); we
    // always cancel first, so a captured container Ref is enough to arm it.
    ref = container.read(Provider<Ref>((ref) => ref));
  });

  tearDown(() {
    container.dispose();
  });

  test('cancelSessionTimeoutCleanupForRequestId disarms the create timer', () {
    const requestId = 987654321;

    AbstractMostroNotifier.startSessionTimeoutCleanupForRequestId(
        requestId, ref);
    expect(AbstractMostroNotifier.hasRequestTimeout(requestId), isTrue);

    AbstractMostroNotifier.cancelSessionTimeoutCleanupForRequestId(requestId);
    expect(AbstractMostroNotifier.hasRequestTimeout(requestId), isFalse);
  });

  test('cancelling is idempotent and safe when already disarmed', () {
    const requestId = 123456789;

    // No timer armed yet: cancel is a no-op.
    AbstractMostroNotifier.cancelSessionTimeoutCleanupForRequestId(requestId);
    expect(AbstractMostroNotifier.hasRequestTimeout(requestId), isFalse);

    AbstractMostroNotifier.startSessionTimeoutCleanupForRequestId(
        requestId, ref);
    AbstractMostroNotifier.cancelSessionTimeoutCleanupForRequestId(requestId);
    // A second cancel (e.g. abandon after the bond handler already cancelled)
    // must not throw and the timer stays gone.
    AbstractMostroNotifier.cancelSessionTimeoutCleanupForRequestId(requestId);
    expect(AbstractMostroNotifier.hasRequestTimeout(requestId), isFalse);
  });
}
