import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mostro_mobile/core/push_registration_wiring.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/services/fcm_service.dart';
import 'package:mostro_mobile/services/push_notification_service.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../mocks.mocks.dart';

/// Records the push calls the wiring makes instead of reaching a server.
class _RecordingSessions extends SessionNotifier {
  _RecordingSessions()
      : super(
          MockRef(),
          MockSessionStorage(),
          Settings(relays: [], fullPrivacyMode: false, mostroPublicKey: 'x'),
        );

  final List<String> calls = [];

  @override
  Future<void> syncPushRegistrations({bool force = false}) async =>
      calls.add(force ? 'sync:forced' : 'sync');

  @override
  Future<void> unregisterPushTokens() async => calls.add('unregister');
}

void main() {
  late _RecordingSessions sessions;
  late SettingsNotifier settings;
  late FCMService fcm;
  late PushNotificationService push;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final prefs = SharedPreferencesAsync();
    sessions = _RecordingSessions();
    settings = SettingsNotifier(prefs);
    fcm = FCMService(prefs);
    push = PushNotificationService(
      fcmService: fcm,
      pushServerUrl: 'https://push.example',
      httpClient: MockClient((_) async => http.Response('{}', 200)),
      isSupportedOverride: true,
    );

    wirePushRegistration(
      sessions: sessions,
      settings: settings,
      pushService: push,
      fcmService: fcm,
    );
  });

  test('a new FCM token forces a re-registration sweep', () async {
    fcm.onTokenRefresh!('new-token');
    await pumpEventQueue();

    expect(sessions.calls, ['sync:forced']);
  });

  test('the push setting toggle drives registration', () async {
    await settings.updatePushNotificationsEnabled(false);
    await settings.pushTransition;
    await settings.updatePushNotificationsEnabled(true);
    await settings.pushTransition;

    expect(sessions.calls, ['unregister', 'sync:forced']);
  });

  test('the push service follows the current settings', () async {
    await settings.updatePushNotificationsEnabled(false);
    expect(push.isPushEnabledInSettings!(), isFalse);

    await settings.updatePushNotificationsEnabled(true);
    expect(push.isPushEnabledInSettings!(), isTrue);

    final node = 'ab' * 32;
    await settings.updateMostroInstance(node);
    expect(push.getMostroPubkey!(), node);
  });
}
