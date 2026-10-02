import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/services/fcm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _RecordingFcmService extends FCMService {
  _RecordingFcmService(super.prefs, this.calls);

  final List<String> calls;

  @override
  Future<void> deleteToken() async => calls.add('deleteToken');
}

void main() {
  late SettingsNotifier notifier;
  late List<String> calls;
  // When set, unregistering blocks until the test completes it, standing in
  // for slow /api/unregister requests.
  Completer<void>? unregisterGate;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final prefs = SharedPreferencesAsync();
    calls = [];
    unregisterGate = null;
    notifier = SettingsNotifier(prefs);
    notifier.setPushServices(
      _RecordingFcmService(prefs, calls),
      registerTokens: () async => calls.add('register'),
      unregisterTokens: () async {
        calls.add('unregister:start');
        await unregisterGate?.future;
        calls.add('unregister:finish');
      },
    );
  });

  test('re-enabling push re-registers the trades', () async {
    await notifier.updatePushNotificationsEnabled(true);
    await notifier.pushTransition;

    expect(calls, ['register']);
  });

  test('disabling push unregisters the trades before deleting the FCM token',
      () async {
    await notifier.updatePushNotificationsEnabled(false);
    await notifier.pushTransition;

    expect(calls, ['unregister:start', 'unregister:finish', 'deleteToken']);
  });

  test('re-enabling during a slow disable registers after the teardown and '
      'keeps the token', () async {
    unregisterGate = Completer<void>();

    await notifier.updatePushNotificationsEnabled(false);
    await pumpEventQueue();
    await notifier.updatePushNotificationsEnabled(true);
    await pumpEventQueue();
    // The enable must wait for the teardown instead of racing it.
    expect(calls, ['unregister:start']);

    unregisterGate!.complete();
    await notifier.pushTransition;

    expect(calls, ['unregister:start', 'unregister:finish', 'register']);
    expect(notifier.state.pushNotificationsEnabled, isTrue);
  });

  test('off, on, off ends disabled without registering', () async {
    unregisterGate = Completer<void>();

    await notifier.updatePushNotificationsEnabled(false);
    await notifier.updatePushNotificationsEnabled(true);
    await notifier.updatePushNotificationsEnabled(false);
    unregisterGate!.complete();
    await notifier.pushTransition;

    expect(calls, isNot(contains('register')));
    expect(calls.last, 'deleteToken');
    expect(notifier.state.pushNotificationsEnabled, isFalse);
  });
}
