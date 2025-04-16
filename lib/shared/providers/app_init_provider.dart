import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/repositories/mostro_storage.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/notifiers/order_action_notifier.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_manager_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appInitializerProvider = FutureProvider<void>((ref) async {
  final nostrService = ref.read(nostrServiceProvider);
  await nostrService.init(ref.read(settingsProvider));

  final keyManager = ref.read(keyManagerProvider);
  await keyManager.init();

  final sessionManager = ref.read(sessionNotifierProvider.notifier);
  await sessionManager.init();

  final mostroService = ref.read(mostroServiceProvider);

  ref.listen<Settings>(settingsProvider, (previous, next) {
    sessionManager.updateSettings(next);
    mostroService.updateSettings(next);
  });

  final mostroStorage = ref.read(mostroStorageProvider);

  for (final session in sessionManager.sessions) {
    if (session.orderId != null) {
      final orderList = await mostroStorage.getMessagesForId(session.orderId!);
      if (orderList.isNotEmpty) {
        ref.read(orderActionNotifierProvider(session.orderId!).notifier).set(
              orderList.last.action,
            );
      }
      ref.read(
        orderNotifierProvider(session.orderId!),
      );
      await mostroService.init();
      mostroService.subscribe(session);
    }

    if (session.peer != null) {
      final chat = ref.watch(
        chatRoomsProvider(session.orderId!).notifier,
      );
      await chat.init();
      chat.subscribe();
    }
  }
});

Future<void> clearAppData(MostroStorage mostroStorage) async {
  final logger = Logger();
  // 1) SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  logger.i("Shared Preferences Cleared");

  // 2) Flutter Secure Storage
  const secureStorage = FlutterSecureStorage();
  await secureStorage.deleteAll();
  logger.i("Shared Storage Cleared");

  // 3) MostroStorage
  mostroStorage.deleteAllMessages();
  logger.i("Mostro Message Storage cleared");
}
