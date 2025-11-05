import 'dart:async';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:dart_nostr/nostr/model/request/request.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/payload.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/features/restore/restore_progress_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/local_notifications_providers.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/notifications_history_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';

class RestoreService {
  
  final Ref ref;
  final Logger _logger = Logger();
  StreamSubscription<NostrEvent>? _tempSubscription;

  RestoreService(this.ref);

  Future<void> importMnemonicAndRestore(String mnemonic) async {
    _logger.i('Restore: importing mnemonic');
    final keyManager = ref.read(keyManagerProvider);
    await keyManager.importMnemonic(mnemonic);
    await initRestoreProcess();
  }

  Future<void> _clearAll() async {
    try {
      await ref.read(sessionNotifierProvider.notifier).reset();
      await ref.read(mostroStorageProvider).deleteAll();
      await ref.read(notificationsRepositoryProvider).clearAll();
      await ref.read(localNotificationsProvider).cancelAll();
    } catch (e) {
      _logger.w('Restore: cleanup error', error: e);
    }
  }

  void _handleTempSubscriptionsResponse(NostrEvent event) {
    _logger.i('Restore: received restore notification event ${event.id}');
    
  }

  Future<StreamSubscription<NostrEvent>> _createTempSubscription() async {
    //use temporary trade key 1 to subscribe to restore notifications
    final keyManager = ref.read(keyManagerProvider);
    final tempTradeKey = await keyManager.deriveTradeKeyFromIndex(1);

    final filter = NostrFilter(
      kinds: [1059],
      p: [tempTradeKey.public],
    );

    final request = NostrRequest(filters: [filter]);
    final stream = ref.read(nostrServiceProvider).subscribeToEvents(request);

    final subscription = stream.listen(
      _handleTempSubscriptionsResponse,
      onError: (error, stackTrace) {
        _logger.e('Restore: subscription error', error: error, stackTrace: stackTrace);
      },
      cancelOnError: false,
    );
    
    return subscription;
  }

  Future<void> _sendRestoreRequest() async {
    _logger.i('Restore: sending restore request');

    final keyManager = ref.read(keyManagerProvider);
    final settings = ref.read(settingsProvider);

    // Use temporary trade key 1 for restore communication
    final tempTradeKey = await keyManager.deriveTradeKeyFromIndex(1);

    // Create restore message with EmptyPayload (serializes as null per protocol spec)
    final mostroMessage = MostroMessage<EmptyPayload>(
      action: Action.restore,
      payload: EmptyPayload(),
    );

    // Respect full privacy mode: if enabled, don't pass master key
    final wrappedEvent = await mostroMessage.wrap(
      tradeKey: tempTradeKey,
      recipientPubKey: settings.mostroPublicKey,
      masterKey: settings.fullPrivacyMode ? null : keyManager.masterKeyPair
    );

    await ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
    _logger.i('Restore: request sent successfully');
  }
  
  //Workflow:
  // 1. Clear existing data
  // 2. Create temporary subscription to key index 1 for restore notifications 
  // 3. Send restore request
  Future<void> restore() async {
    //Clear existing data
    await _clearAll();

    //Show restore overlay
    final progress = ref.read(restoreProgressProvider.notifier);
    progress.startRestore();

    //Validate master key
    final keyManager = ref.read(keyManagerProvider);
    if (keyManager.masterKeyPair == null) {
      _logger.e('Restore: master key not found after import');
      throw Exception('Master key not found');
    }

    //Validate Mostro public key
    final settings = ref.read(settingsProvider);
    if (settings.mostroPublicKey.isEmpty) {
      _logger.e('Restore: Mostro not configured');
      throw Exception('Mostro not configured');
    }

    //Subscribe to temporary notifications
    _tempSubscription = await _createTempSubscription();

    //Send restore request
    await _sendRestoreRequest();

    await Future.delayed(const Duration(seconds: 3));
   _tempSubscription?.cancel();

  }


//  Future<JSONMessageCodec> _buildRestoreRequest() async {
    
 // }

//Future<void> _buildOrderDetailsRequest(List<String> orderIds) async {
 // }


 


}

final restoreServiceProvider = Provider<RestoreService>((ref) {
  return RestoreService(ref);
});