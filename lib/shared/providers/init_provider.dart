import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/shared/providers/key_manager_provider.dart';

final appInitializerProvider = FutureProvider<void>((ref) async {
  final keyManager = ref.read(keyManagerProvider);

  // Check if master key exists
  bool hasMaster = await keyManager.hasMasterKey();

  if (!hasMaster) {
    // First run: Generate and store master key
    await keyManager.generateAndStoreMasterKey();
  }
});