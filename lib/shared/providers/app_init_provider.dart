import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appInitializerProvider = FutureProvider<void>((ref) async {
  final keyManager = ref.read(keyManagerProvider);
  bool hasMaster = await keyManager.hasMasterKey();
  if (!hasMaster) {
    await keyManager.generateAndStoreMasterKey();
  }

  final mostroRepository = ref.read(mostroRepositoryProvider);
  await mostroRepository.loadMessages();

  for (final msg in mostroRepository.allMessages) {
    final orderId = msg.id!;
    ref.read(orderNotifierProvider(orderId).notifier);
  }
});

Future<void> clearAppData() async {
  // 1) SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();

  // 2) Flutter Secure Storage
  const secureStorage = FlutterSecureStorage();
  await secureStorage.deleteAll();
}
