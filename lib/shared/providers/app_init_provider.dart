import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/services/fcm_service.dart';
import 'package:mostro_mobile/shared/providers/background_service_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/features/notifications/services/background_notification_service.dart';

/// Check if the current platform supports Firebase
bool get _isFirebaseSupported {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}

final appInitializerProvider = FutureProvider<void>((ref) async {
  final logger = Logger();

  logger.i('=== APP INITIALIZATION STARTED ===');

  final nostrService = ref.read(nostrServiceProvider);
  await nostrService.init(ref.read(settingsProvider));

  // Initialize FCM only on supported platforms (Android, iOS)
  if (_isFirebaseSupported) {
    final fcmService = ref.read(fcmServiceProvider);
    try {
      await fcmService.initialize(
        onMessageReceived: () async {
          final settings = ref.read(settingsProvider);
          final relays = settings.relays;

          if (relays.isEmpty) {
            logger.w('No relays configured - cannot fetch events');
            return;
          }

          await fetchAndProcessNewEvents(relays: relays);
        },
      );
    } catch (e, stackTrace) {
      logger.e('FCM initialization failed: $e', error: e, stackTrace: stackTrace);
    }
  } else {
    logger.i('FCM not supported on this platform - skipping FCM initialization');
  }

  final keyManager = ref.read(keyManagerProvider);
  await keyManager.init();

  final sessionManager = ref.read(sessionNotifierProvider.notifier);
  await sessionManager.init();

  ref.read(subscriptionManagerProvider);

  ref.listen<Settings>(settingsProvider, (previous, next) {
    ref.read(backgroundServiceProvider).updateSettings(next);
  });

  final cutoff = DateTime.now().subtract(const Duration(hours: Config.sessionExpirationHours));

  for (final session in sessionManager.sessions) {
    if(session.orderId == null || session.startTime.isBefore(cutoff)) continue;

    ref.read(orderNotifierProvider(session.orderId!).notifier);

    if (session.peer != null) {
      ref.read(chatRoomsProvider(session.orderId!).notifier).subscribe();
    }
  }

  logger.i('=== APP INITIALIZATION COMPLETED ===');
});
