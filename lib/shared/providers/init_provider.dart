import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';

final appInitializerProvider = FutureProvider<void>((ref) async {
  final flutterSecureStorage = ref.read(secureStorageProvider);
  flutterSecureStorage.deleteAll();
  final keyManager = ref.read(keyManagerProvider);
  bool hasMaster = await keyManager.hasMasterKey();
  if (!hasMaster) {
    await keyManager.generateAndStoreMasterKey();
  }
});
