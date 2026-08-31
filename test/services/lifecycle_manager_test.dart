import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/services/lifecycle_manager.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../mocks.mocks.dart';

/// On Android, `AppLifecycleState.inactive` fires for the notification shade,
/// permission/biometric dialogs and the app switcher. Treating it as
/// "backgrounded" made each blip cost a full unsubscribe + background-service
/// start, and the matching resume redid cold-start work (subscribeAll, order
/// book reload, full chat history re-decrypt) — the main "slow after being
/// open a while" driver. Only a sustained paused/hidden/detached state may
/// switch to background, after a debounce that a quick resume cancels.
void main() {
  late MockSubscriptionManagerSpy manager;
  late ProviderContainer container;
  late LifecycleManager lifecycle;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    manager = MockSubscriptionManagerSpy();
    when(manager.getActiveFilters(any)).thenReturn([]);
    container = ProviderContainer(overrides: [
      subscriptionManagerProvider.overrideWithValue(manager),
    ]);
  });

  tearDown(() {
    lifecycle.dispose();
    container.dispose();
  });

  LifecycleManager build() => LifecycleManager(
        _RefAdapter(container),
        isMobilePlatform: true,
      );

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(LifecycleManager.backgroundDebounce);
    await tester.pump();
  }

  testWidgets('inactive does not switch to background', (tester) async {
    lifecycle = build();

    lifecycle.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await settle(tester);

    expect(lifecycle.isInBackground, isFalse);
    verifyNever(manager.unsubscribeAll());
  });

  testWidgets('paused switches to background after the debounce',
      (tester) async {
    lifecycle = build();

    lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(lifecycle.isInBackground, isFalse,
        reason: 'the switch must wait for the debounce window');
    await settle(tester);

    expect(lifecycle.isInBackground, isTrue);
  });

  testWidgets(
      'a return that stalls in inactive cancels the pending background switch',
      (tester) async {
    // The return path is paused -> hidden -> inactive -> resumed, and the app
    // can sit in `inactive` for a while behind a permission or biometric
    // dialog. If the debounce fires there, the whole teardown runs while the
    // app is already foregrounding.
    lifecycle = build();

    // Arrange: backgrounded, switch pending but not yet fired.
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump(LifecycleManager.backgroundDebounce -
        const Duration(milliseconds: 100));

    // Act: the user comes back, then a dialog holds the app in `inactive`
    // well past the original deadline.
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.hidden);
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    // Assert
    expect(lifecycle.isInBackground, isFalse);
    verifyNever(manager.unsubscribeAll());
  });

  testWidgets('leaving inactive outwards reschedules the switch',
      (tester) async {
    // Cancelling on `inactive` must not strand the manager in the foreground:
    // going further out delivers `hidden`, which schedules again.
    lifecycle = build();

    lifecycle.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 100));
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.hidden);
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
    await settle(tester);

    expect(lifecycle.isInBackground, isTrue);
  });

  testWidgets('a quick resume cancels a pending background switch',
      (tester) async {
    lifecycle = build();

    lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 100));
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await settle(tester);

    expect(lifecycle.isInBackground, isFalse);
    verifyNever(manager.unsubscribeAll());
    verifyNever(manager.subscribeAll());
  });
}

/// Minimal Ref façade over a container for unit-testing the manager.
class _RefAdapter implements Ref {
  _RefAdapter(this.container);

  @override
  final ProviderContainer container;

  @override
  T read<T>(ProviderListenable<T> provider) => container.read(provider);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
