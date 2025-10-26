import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/last_trade_index_message.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';

class LastTradeIndexService {
  final Ref ref;
  final Logger _logger = Logger();

  LastTradeIndexService(this.ref);

  Future<void> requestLastTradeIndex() async {
    final keyManager = ref.read(keyManagerProvider);
    final masterKey = keyManager.masterKeyPair;

    if (masterKey == null) {
      _logger.w('Cannot request last trade index: no master key');
      return;
    }

    final settings = ref.read(settingsProvider);
    final request = LastTradeIndexRequest();

    // Ensure MostroService is initialized to receive admin messages
    ref.read(mostroServiceProvider);

    final rumor = NostrEvent.fromPartialData(
      keyPairs: masterKey,
      content: request.toJsonString(),
      kind: 1,
      tags: [],
    );

    final wrappedEvent = await rumor.mostroWrap(
      masterKey,
      settings.mostroPublicKey,
    );

    await ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
    _logger.i('Requested last trade index');
  }

  Future<void> processLastTradeIndex(int tradeIndex) async {
    final keyManager = ref.read(keyManagerProvider);
    await keyManager.setCurrentKeyIndex(tradeIndex + 1);
    _logger.i('Updated key index to ${tradeIndex + 1}');
  }
}

final lastTradeIndexServiceProvider = Provider<LastTradeIndexService>((ref) {
  return LastTradeIndexService(ref);
});
