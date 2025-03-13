import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/repositories/mostro_storage.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_manager_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appInitializerProvider = FutureProvider<void>((ref) async {
  final nostrService = ref.read(nostrServiceProvider);
  await nostrService.init();

  final keyManager = ref.read(keyManagerProvider);
  bool hasMaster = await keyManager.hasMasterKey();
  if (!hasMaster) {
    await keyManager.generateAndStoreMasterKey();
  }

  final sessionManager = ref.read(sessionManagerProvider);
  await sessionManager.init();

  final mostroService = ref.read(mostroServiceProvider);

  ref.listen<Settings>(settingsProvider, (previous, next) {
    sessionManager.updateSettings(next);
    mostroService.updateSettings(next);
  });

  for (final session in sessionManager.sessions) {
    if (session.orderId != null) {
      final order = ref.watch(orderNotifierProvider(session.orderId!).notifier);
      order.resubscribe();
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
  mostroStorage.deleteAllOrders();
  logger.i("Mostro Message Storage cleared");
}
