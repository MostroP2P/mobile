import 'dart:async';
import 'dart:convert';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:dart_nostr/nostr/model/request/request.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/orders_request.dart';
import 'package:mostro_mobile/data/models/orders_response.dart';
import 'package:mostro_mobile/data/models/payload.dart';
import 'package:mostro_mobile/data/models/restore_response.dart';
import 'package:mostro_mobile/data/models/last_trade_index_response.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/restore/restore_progress_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/notifications_history_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';


enum RestoreStage {
  gettingRestoreData,
  gettingOrdersDetails,
  gettingTradeIndex,
}

class RestoreService {

  final Ref ref;
  final Logger _logger = Logger();
  StreamSubscription<NostrEvent>? _tempSubscription;
  Completer<NostrEvent>? _currentCompleter;
  RestoreStage _currentStage = RestoreStage.gettingRestoreData;

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
      await ref.read(eventStorageProvider).deleteAll();
      await ref.read(notificationsRepositoryProvider).clearAll();
      
    } catch (e) {
      _logger.w('Restore: cleanup error', error: e);
    }
  }

  Future<NostrEvent> _waitForEvent(RestoreStage stage, {Duration timeout = const Duration(seconds: 10)}) async {
    _currentStage = stage;
    _currentCompleter = Completer<NostrEvent>();

    try {
      final event = await _currentCompleter!.future.timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException('Stage $stage timed out after ${timeout.inSeconds}s');
        },
      );
      _logger.i('Restore: stage $_currentStage completed - Event: ${event.id}');
      return event;
    } catch (e) {
      _logger.e('Restore: stage $_currentStage failed', error: e);
      rethrow;
    }
  }

  void _handleTempSubscriptionsResponse(NostrEvent event) {
    if (_currentCompleter != null && !_currentCompleter!.isCompleted) {
      _currentCompleter!.complete(event);
    }
  }

  Future<StreamSubscription<NostrEvent>> _createTempSubscription() async {
    //use temporary trade key 1 to subscribe to restore notifications
    final keyManager = ref.read(keyManagerProvider);
    final tempTradeKey = await keyManager.deriveTradeKeyFromIndex(1);

    final filter = NostrFilter(
      kinds: [1059],
      p: [tempTradeKey.public],
      limit: 0, //IMPORTANT:  limit 0 indicates we don’t want historical events, only new ones https://nostrbook.dev/protocol/filter
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
    
    _logger.i('Restore: temporary subscription created');
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

  Future<Map<String,int>> _extractRestoreData(NostrEvent event) async {
    try {

      final keyManager = ref.read(keyManagerProvider);
      final tempTradeKey = await keyManager.deriveTradeKeyFromIndex(1);

      // Unwrap the gift wrap (kind 1059) to get the rumor
      final rumor = await event.mostroUnWrap(tempTradeKey);

      if (rumor.content == null || rumor.content!.isEmpty) {
        throw Exception('Rumor content is empty');
      }

      final contentList = jsonDecode(rumor.content!) as List<dynamic>;
      final messageData = contentList[0] as Map<String, dynamic>;

      // Extract payload from restore wrapper
      final restoreWrapper = messageData['restore'] as Map<String, dynamic>;
      final payload = restoreWrapper['payload'] as Map<String, dynamic>;

      final restoreData = RestoreData.fromJson(payload);

      Map<String, int> orderIds = {};

      for (var order in restoreData.orders) {
        orderIds[order.id] = order.tradeIndex;
      }

      for (var dispute in restoreData.disputes) {
        orderIds[dispute.orderId] = dispute.tradeIndex;
      }

      return orderIds;
    } catch (e, stack) {
      _logger.e('Restore: failed to extract restore data', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> _sendOrdersDetailsRequest(List<String> orderIds) async {
    _logger.i('Restore: sending orders details request for ${orderIds.length} orders');

    final keyManager = ref.read(keyManagerProvider);
    final settings = ref.read(settingsProvider);
    final tempTradeKey = await keyManager.deriveTradeKeyFromIndex(1);

    // Create orders message following same pattern as restore
    final mostroMessage = MostroMessage<OrdersPayload>(
      action: Action.orders,
      requestId: DateTime.now().millisecondsSinceEpoch,
      payload: OrdersPayload(ids: orderIds),
    );

    final wrappedEvent = await mostroMessage.wrap(
      tradeKey: tempTradeKey,
      recipientPubKey: settings.mostroPublicKey,
      masterKey: settings.fullPrivacyMode ? null : keyManager.masterKeyPair
    );

    await ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
    _logger.i('Restore: orders details request sent successfully');
  }

  Future<OrdersResponse> _extractOrdersDetails(NostrEvent event) async {
    try {
      _logger.i('Restore: extracting orders details from gift wrap event ${event.id}');

      final keyManager = ref.read(keyManagerProvider);
      final tempTradeKey = await keyManager.deriveTradeKeyFromIndex(1);

      // Unwrap the gift wrap (kind 1059) to get the rumor
      final rumor = await event.mostroUnWrap(tempTradeKey);
      _logger.i('Restore: unwrapped rumor event ${rumor.id}');

      if (rumor.content == null || rumor.content!.isEmpty) {
        throw Exception('Rumor content is empty');
      }

      // Parse response format: [{"order": {...}}, null]
      final contentList = jsonDecode(rumor.content!) as List<dynamic>;
      final messageData = contentList[0] as Map<String, dynamic>;

      // Extract payload from order wrapper
      final orderWrapper = messageData['order'] as Map<String, dynamic>;
      final payload = orderWrapper['payload'] as Map<String, dynamic>;

      final ordersResponse = OrdersResponse.fromJson(payload);

      _logger.i('Restore: found ${ordersResponse.orders.length} order details');

      for (var order in ordersResponse.orders) {
        _logger.i('Restore: Order ${order.id} - status: ${order.status}, amount: ${order.amount} sats');
      }

      return ordersResponse;
    } catch (e, stack) {
      _logger.e('Restore: failed to extract orders details', error: e, stackTrace: stack);
      rethrow;
    }
  }

  //Workflow:
  // 1. Clear existing data
  // 2. Create temporary subscription to key index 1 for restore notifications
  // 3. Send restore request and wait for response (Stage 1: GettingRestoreData)
  // 4. Process restore data and request order details (Stage 2: GettingOrdersDetails)
  
  Future<void> initRestoreProcess() async {
    try {
      // Clear existing data
      await _clearAll();

      // Show restore overlay
      final progress = ref.read(restoreProgressProvider.notifier);
      progress.startRestore();

      // Validate master key
      final keyManager = ref.read(keyManagerProvider);
      if (keyManager.masterKeyPair == null) {
        _logger.e('Restore: master key not found after import');
        throw Exception('Master key not found');
      }

      // Validate Mostro public key
      final settings = ref.read(settingsProvider);
      if (settings.mostroPublicKey.isEmpty) {
        _logger.e('Restore: Mostro not configured');
        throw Exception('Mostro not configured');
      }

      // Subscribe to temporary notifications
      _tempSubscription = await _createTempSubscription();

      // STAGE 1: Getting Restore Data
      await _sendRestoreRequest();
      final restoreDataEvent = await _waitForEvent(RestoreStage.gettingRestoreData);
      final restoreData = await _extractRestoreData(restoreDataEvent);
      progress.setOrdersReceived(restoreData.length);

      if (restoreData.isEmpty) { 
        _logger.w('Restore: no orders or disputes to restore');
        return;
      }

      // STAGE 2: Getting Orders Details
      await _sendOrdersDetailsRequest(restoreData.keys.toList());
      final ordersDetailsEvent = await _waitForEvent(RestoreStage.gettingOrdersDetails);
      final ordersResponse = await _extractOrdersDetails(ordersDetailsEvent);

      _logger.i('Restore: processing ${ordersResponse.toJson()} orders');

    

    } on TimeoutException catch (e, stack) {
      _logger.e('Restore: timeout error', error: e, stackTrace: stack);
      rethrow;
    } catch (e, stack) {
      _logger.e('Restore: error during restore process', error: e, stackTrace: stack);
      rethrow;
    } finally {
      // Cleanup: always cancel subscription
      _logger.i('Restore: cleaning up subscription');
      _tempSubscription = null;
      _currentCompleter = null;
      ref.read(restoreProgressProvider.notifier).completeRestore();  
    }
  }
}

final restoreServiceProvider = Provider<RestoreService>((ref) {
  return RestoreService(ref);
});