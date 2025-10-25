import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/restore_data.dart';
import 'package:mostro_mobile/data/models/restore_message.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';

class RestoreService {
  final Ref ref;
  final Logger _logger = Logger();

  RestoreService(this.ref);

  Future<void> importMnemonicAndRestore(String mnemonic) async {
    _logger.i('Starting restore session');

    final keyManager = ref.read(keyManagerProvider);
    await keyManager.importMnemonic(mnemonic);

    final settings = ref.read(settingsProvider);
    if (settings.mostroPublicKey.isEmpty) {
      throw Exception('Mostro public key not configured');
    }

    final masterKey = keyManager.masterKeyPair!;
    final sessionNotifier = ref.read(sessionNotifierProvider.notifier);

    final tempSession = Session(
      masterKey: masterKey,
      tradeKey: masterKey,
      keyIndex: 0,
      fullPrivacy: settings.fullPrivacyMode,
      startTime: DateTime.now(),
      orderId: '__restore__',
    );

    await sessionNotifier.saveSession(tempSession);
    ref.read(mostroServiceProvider);

    final restoreMessage = RestoreMessage();
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

    await ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
    _logger.i('Restore request sent');
  }

  Future<void> processRestoreData(Map<String, dynamic> payload) async {

    final restoreData = RestoreData.fromJson(payload);
    final keyManager = ref.read(keyManagerProvider);
    final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
    final settings = ref.read(settingsProvider);

    _logger.i('Parsed restore data: ${restoreData.orders.length} orders, ${restoreData.disputes.length} disputes');

    for (final order in restoreData.orders) {
      final tradeKey = await keyManager.deriveTradeKeyFromIndex(order.tradeIndex);
      final masterKey = keyManager.masterKeyPair!;

      final session = Session(
        masterKey: masterKey,
        tradeKey: tradeKey,
        keyIndex: order.tradeIndex,
        fullPrivacy: settings.fullPrivacyMode,
        startTime: DateTime.now(),
        orderId: order.id,
      );

      await sessionNotifier.saveSession(session);
      _logger.i('Restored order ${order.id}');
    }

    await sessionNotifier.deleteSession('__restore__');
    _logger.i('Restored ${restoreData.orders.length} orders successfully');
  }
}

final restoreServiceProvider = Provider<RestoreService>((ref) {
  return RestoreService(ref);
});