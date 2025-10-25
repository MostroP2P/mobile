import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/restore_message.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';

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

    // 3. Send restore-session request to Mostro
    final masterKey = keyManager.masterKeyPair;
    final settings = ref.read(settingsProvider);

    if (masterKey == null) {
      throw Exception('Master key not available after import');
    }

    final rumor = NostrEvent.fromPartialData(
      keyPairs: masterKey,
      content: restoreMessage.toJsonString(),
      kind: 1,
      tags: [],
    );

    final wrappedEvent = await rumor.mostroWrap(
      masterKey,
      settings.mostroPublicKey,
    );

    _logger.i('Sending restore-session gift wrap to Mostro');
    await ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
    _logger.i('Restore-session request sent successfully');
  }
}

final restoreServiceProvider = Provider<RestoreService>((ref) {
  return RestoreService(ref);
});