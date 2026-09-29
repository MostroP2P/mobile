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

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final prefs = SharedPreferencesAsync();
    calls = [];
    notifier = SettingsNotifier(prefs);
    notifier.setPushServices(
      _RecordingFcmService(prefs, calls),
      registerTokens: () async => calls.add('register'),
      unregisterTokens: () async => calls.add('unregister'),
    );
  });

  test('re-enabling push re-registers the trades', () async {
    await notifier.updatePushNotificationsEnabled(true);
    await pumpEventQueue();

    expect(calls, ['register']);
  });

  test('disabling push unregisters the trades before deleting the FCM token',
      () async {
    await notifier.updatePushNotificationsEnabled(false);
    await pumpEventQueue();

    expect(calls, ['unregister', 'deleteToken']);
  });
}
