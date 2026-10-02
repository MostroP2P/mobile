import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/services/fcm_service.dart';
import 'package:mostro_mobile/services/push_notification_service.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';

/// Connects push registration to the trades ([sessions]) and to the push
/// setting ([settings]).
void wirePushRegistration({
  required SessionNotifier sessions,
  required SettingsNotifier settings,
  required PushNotificationService pushService,
  required FCMService fcmService,
}) {
  // Connect push service with session notifier for automatic token registration
  sessions.setPushNotificationService(pushService);

  // Toggling push in settings drops or restores every trade's registration
  settings.setPushServices(
    fcmService,
    registerTokens: () => sessions.syncPushRegistrations(force: true),
    unregisterTokens: sessions.unregisterPushTokens,
  );

  // A new FCM token invalidates every registration made with the old one
  fcmService.onTokenRefresh =
      (_) => sessions.syncPushRegistrations(force: true);

  // Registration follows the current push setting
  pushService.isPushEnabledInSettings =
      () => settings.settings.pushNotificationsEnabled;

  // Provide the active Mostro instance pubkey for /api/register
  pushService.getMostroPubkey = () => settings.settings.mostroPublicKey;
}
