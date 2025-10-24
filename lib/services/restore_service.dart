import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/restore_message.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';

class RestoreService {
  final Ref ref;
  final Logger _logger = Logger();

  RestoreService(this.ref);

  Future<void> importMnemonicAndRestore(String mnemonic) async {
    // 1. Import mnemonic
    final keyManager = ref.read(keyManagerProvider);
    await keyManager.importMnemonic(mnemonic);

    // 2. Create restore-session request
    final restoreMessage = RestoreMessage();
    _logger.i('Restore request JSON: ${restoreMessage.toJsonString()}');

    // TODO: Send restore-session request to Mostro
    // final masterKey = keyManager.masterKeyPair;
    // final settings = ref.read(settingsProvider);
    // final event = await restoreMessage.wrap(
    //   masterKey: masterKey!,
    //   mostroPubKey: settings.mostroPublicKey,
    // );
    // await ref.read(nostrServiceProvider).publishEvent(event);
  }
}

final restoreServiceProvider = Provider<RestoreService>((ref) {
  return RestoreService(ref);
});