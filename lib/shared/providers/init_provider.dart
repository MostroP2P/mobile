import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';

final appInitializerProvider = FutureProvider<void>((ref) async {
  final keyManager = ref.read(keyManagerProvider);
  bool hasMaster = await keyManager.hasMasterKey();
  if (!hasMaster) {
    await keyManager.generateAndStoreMasterKey();
  }
  final mostroRepository = ref.read(mostroRepositoryProvider);
  await mostroRepository.loadMessages();

  for (final msg in mostroRepository.allMessages) {
    final orderId = msg.requestId!;
    ref.read(orderNotifierProvider(orderId).notifier);
  }
});
