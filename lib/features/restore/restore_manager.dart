import 'dart:async';
import 'dart:convert';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:dart_nostr/nostr/model/request/request.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/last_trade_index_response.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/orders_request.dart';
import 'package:mostro_mobile/data/models/orders_response.dart';
import 'package:mostro_mobile/data/models/payload.dart';
import 'package:mostro_mobile/data/models/restore_response.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/restore/restore_progress_notifier.dart';
import 'package:mostro_mobile/features/restore/restore_progress_state.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/navigation_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/notifications_history_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:mostro_mobile/features/order/notfiers/abstract_mostro_notifier.dart';


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

    // Import the mnemonic - this saves to storage
    final keyManager = ref.read(keyManagerProvider);
    await keyManager.importMnemonic(mnemonic);
    _logger.i('Restore: mnemonic imported and saved to storage');

    // Invalidate keyManagerProvider to force re-initialization
    // This ensures all providers get a fresh instance with the new key
    ref.invalidate(keyManagerProvider);
    _logger.i('Restore: invalidated keyManagerProvider');

    // Get the new instance and initialize it
    final newKeyManager = ref.read(keyManagerProvider);
    await newKeyManager.init();
    _logger.i('Restore: new keyManager initialized, masterKeyPair=${newKeyManager.masterKeyPair != null}');

    await initRestoreProcess();
  }

  Future<void> _clearAll() async {
    try {
      await ref.read(sessionNotifierProvider.notifier).reset();
      await ref.read(mostroStorageProvider).deleteAll();
      await ref.read(eventStorageProvider).deleteAll();
      await ref.read(notificationsRepositoryProvider).clearAll();
      ref.read(orderRepositoryProvider).clearCache();

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

  Future<({Map<String, int> orderIds, List<RestoredDispute> disputes})> _extractRestoreData(NostrEvent event) async {
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

      // Check if Mostro returned cant-do (not found)
      if (messageData.containsKey('cant-do')) {
        _logger.w('Restore: Mostro returned cant-do for restore data (no orders found)');
        return (orderIds: <String, int>{}, disputes: <RestoredDispute>[]);
      }

      // Extract payload from restore wrapper
      final restoreWrapper = messageData['restore'] as Map<String, dynamic>?;

      if (restoreWrapper == null) {
        _logger.w('Restore: no restore wrapper found, returning empty orders');
        return (orderIds: <String, int>{}, disputes: <RestoredDispute>[]);
      }

      final payload = restoreWrapper['payload'] as Map<String, dynamic>?;

      if (payload == null) {
        _logger.w('Restore: no payload found in restore wrapper, returning empty orders');
        return (orderIds: <String, int>{}, disputes: <RestoredDispute>[]);
      }

      final restoreData = RestoreData.fromJson(payload);

      final Map<String, int> orderIds = <String, int>{};

      for (var order in restoreData.orders) {
        orderIds[order.id] = order.tradeIndex;
      }

      for (var dispute in restoreData.disputes) {
        orderIds[dispute.orderId] = dispute.tradeIndex;
      }

      final List<RestoredDispute> disputesList = restoreData.disputes;

      return (orderIds: orderIds, disputes: disputesList);
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

  Future<void> _sendLastTradeIndexRequest() async {
    _logger.i('Restore: sending last trade index request');

    final keyManager = ref.read(keyManagerProvider);
    final settings = ref.read(settingsProvider);
    final tempTradeKey = await keyManager.deriveTradeKeyFromIndex(1);

    // Create last-trade-index message with EmptyPayload (serializes as null per protocol spec)
    final mostroMessage = MostroMessage<EmptyPayload>(
      action: Action.lastTradeIndex,
      payload: EmptyPayload(),
    );

    final wrappedEvent = await mostroMessage.wrap(
      tradeKey: tempTradeKey,
      recipientPubKey: settings.mostroPublicKey,
      masterKey: settings.fullPrivacyMode ? null : keyManager.masterKeyPair
    );

    await ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
    _logger.i('Restore: last trade index request sent successfully');
  }

  Future<LastTradeIndexResponse> _extractLastTradeIndex(NostrEvent event) async {
    try {
      _logger.i('Restore: extracting last trade index from gift wrap event ${event.id}');

      final keyManager = ref.read(keyManagerProvider);
      final tempTradeKey = await keyManager.deriveTradeKeyFromIndex(1);

      // Unwrap the gift wrap (kind 1059) to get the rumor
      final rumor = await event.mostroUnWrap(tempTradeKey);
      _logger.i('Restore: unwrapped rumor event ${rumor.id}');

      if (rumor.content == null || rumor.content!.isEmpty) {
        throw Exception('Rumor content is empty');
      }

      final contentList = jsonDecode(rumor.content!) as List<dynamic>;
      final messageData = contentList[0] as Map<String, dynamic>;

      // Check if Mostro returned cant-do (not found)
      if (messageData.containsKey('cant-do')) {
        _logger.w('Restore: Mostro returned cant-do for last trade index, defaulting to 0');
        return LastTradeIndexResponse(tradeIndex: 0);
      }

      // Extract trade_index from restore wrapper
      final restoreWrapper = messageData['restore'] as Map<String, dynamic>?;

      if (restoreWrapper == null) {
        _logger.w('Restore: no restore wrapper found, defaulting trade index to 0');
        return LastTradeIndexResponse(tradeIndex: 0);
      }

      final response = LastTradeIndexResponse.fromJson(restoreWrapper);

      _logger.i('Restore: last trade index is ${response.tradeIndex}');

      return response;
    } catch (e, stack) {
      _logger.e('Restore: failed to extract last trade index', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Determines if the user initiated the dispute based on available information
  bool _determineIfUserInitiatedDispute({
    required RestoredDispute restoredDispute,
    required Order order,
    Session? session,
  }) {
    // Without session role, we can't determine who initiated
    if (session?.role == null) {
      _logger.w('Restore: cannot determine dispute initiator, no session role for order ${order.id}');
      return false; // Default to peer-initiated
    }

    // Check trade pubkeys to determine who initiated
    // The user is either buyer or seller based on session.role
    final userPubkey = session!.tradeKey.public;
    final isBuyer = session.role == Role.buyer;

    // Compare with order pubkeys to determine if user initiated
    // This logic depends on how dispute initiator info is stored
    // For now, we'll use a heuristic: if user is buyer and buyerTradePubkey matches, user initiated
    if (isBuyer && order.buyerTradePubkey == userPubkey) {
      return true; // User is buyer and likely initiated
    } else if (!isBuyer && order.sellerTradePubkey == userPubkey) {
      return true; // User is seller and likely initiated
    }

    // Default to peer-initiated if we can't determine
    return false;
  }

  /// Maps Status to the appropriate Action for restored orders
  Action _getActionFromStatus(Status status) {
    switch (status) {
      case Status.pending:
        return Action.newOrder;
      case Status.waitingBuyerInvoice:
        return Action.waitingBuyerInvoice;
      case Status.waitingPayment:
        return Action.waitingSellerToPay;
      case Status.active:
        return Action.buyerTookOrder;
      case Status.fiatSent:
        return Action.fiatSentOk;
      case Status.settledHoldInvoice:
        return Action.holdInvoicePaymentSettled;
      case Status.success:
        return Action.purchaseCompleted;
      case Status.canceled:
        return Action.canceled;
      case Status.canceledByAdmin:
        return Action.adminCanceled;
      case Status.settledByAdmin:
        return Action.adminSettled;
      case Status.completedByAdmin:
        return Action.adminSettled;
      case Status.dispute:
        return Action.disputeInitiatedByPeer; //No should be used -  Default to peer-initiated
      case Status.expired:
        return Action.canceled;
      case Status.paymentFailed:
        return Action.paymentFailed;
      case Status.cooperativelyCanceled:
        return Action.cooperativeCancelAccepted;
      case Status.inProgress:
        return Action.buyerTookOrder;
    }
  }

  Future<void> restore(Map<String, int> ordersIds, int lastTradeIndex, OrdersResponse ordersResponse, List<RestoredDispute> disputes) async {
    try {

      final keyManager = ref.read(keyManagerProvider);
      final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
      final progress = ref.read(restoreProgressProvider.notifier);
      final settings = ref.read(settingsProvider);


      // Set the next trade key index
      await keyManager.setCurrentKeyIndex(lastTradeIndex + 1);

      // Get master key
      final masterKey = keyManager.masterKeyPair;
      if (masterKey == null) {
        throw Exception('Master key not available');
      }

      // Restore each order as a session
      for (final entry in ordersIds.entries) {
        final orderId = entry.key;
        final tradeIndex = entry.value;

        // Find the order detail for this orderId
        final orderDetail = ordersResponse.orders.firstWhere(
          (order) => order.id == orderId,
          orElse: () => throw Exception('Order detail not found for orderId: $orderId'),
        );

        // Derive trade key for this trade index
        final tradeKey = keyManager.deriveTradeKeyPair(tradeIndex);

        // Determine role by comparing trade keys
        Role? role;
        if (orderDetail.buyerTradePubkey != null && orderDetail.buyerTradePubkey == tradeKey.public) {
          role = Role.buyer;
        } else if (orderDetail.sellerTradePubkey != null && orderDetail.sellerTradePubkey == tradeKey.public) {
          role = Role.seller;
        }

        final session = Session(
          masterKey: masterKey,
          tradeKey: tradeKey,
          keyIndex: tradeIndex,
          fullPrivacy: settings.fullPrivacyMode,
          startTime: DateTime.now(),
          orderId: orderDetail.id,
          role: role,
        );

        // Store session
        await sessionNotifier.saveSession(session);

        _logger.i('Restore: created session for order ${orderDetail.id} (isRestored: true)');

        progress.incrementProgress();
      }

      // Enable restore mode to block all message processing
      AbstractMostroNotifier.setRestoring(true);
      _logger.i('Restore: enabled restore mode - blocking all message processing');

      // Wait for historical messages to arrive and be saved to storage
      _logger.i('Restore: waiting 5 seconds for historical messages to be saved...');
      await Future.delayed(const Duration(seconds: 5));

      // Build MostroMessages from ordersResponse and update state (source of truth from Mostro)
      _logger.i('Restore: building messages for ${ordersResponse.orders.length} orders from ordersResponse');
      final storage = ref.read(mostroStorageProvider);

      for (final orderDetail in ordersResponse.orders) {
        try {
          // Convert OrderDetail to Order
          final order = Order(
            id: orderDetail.id,
            kind: OrderType.fromString(orderDetail.kind),
            status: Status.fromString(orderDetail.status),
            amount: orderDetail.amount,
            fiatCode: orderDetail.fiatCode,
            minAmount: orderDetail.minAmount,
            maxAmount: orderDetail.maxAmount,
            fiatAmount: orderDetail.fiatAmount,
            paymentMethod: orderDetail.paymentMethod,
            premium: orderDetail.premium,
            buyerTradePubkey: orderDetail.buyerTradePubkey,
            sellerTradePubkey: orderDetail.sellerTradePubkey,
            createdAt: orderDetail.createdAt,
            expiresAt: orderDetail.expiresAt,
          );

          // Check if this order has a dispute
          final restoredDispute = disputes.where((d) => d.orderId == orderDetail.id).firstOrNull;

          // Determine action and create dispute if needed
          Action action;
          Dispute? dispute;

          if (restoredDispute != null && order.status == Status.dispute) {
            // This is a disputed order - determine who initiated
            final session = ref.read(sessionNotifierProvider.notifier).getSessionByOrderId(orderDetail.id);

            // Determine if user initiated the dispute
            // If user is buyer and buyer initiated, or user is seller and seller initiated
            final userInitiated = _determineIfUserInitiatedDispute(
              restoredDispute: restoredDispute,
              order: order,
              session: session,
            );

            action = userInitiated
                ? Action.disputeInitiatedByYou
                : Action.disputeInitiatedByPeer;

            // Create Dispute object
            dispute = Dispute(
              disputeId: restoredDispute.disputeId,
              orderId: restoredDispute.orderId,
              status: restoredDispute.status,
              createdAt: orderDetail.createdAt != null
                  ? DateTime.fromMillisecondsSinceEpoch(orderDetail.createdAt!)
                  : DateTime.now(),
              action: userInitiated ? 'dispute-initiated-by-you' : 'dispute-initiated-by-peer',
            );

            _logger.i('Restore: dispute found for order ${orderDetail.id}, action: $action');
          } else {
            // Regular order without dispute
            action = _getActionFromStatus(order.status);
          }

          // Build MostroMessage with Order payload
          final mostroMessage = MostroMessage<Order>(
            id: orderDetail.id,
            action: action,
            payload: order,
            timestamp: orderDetail.createdAt ?? DateTime.now().millisecondsSinceEpoch,
          );

          // Save message to storage for future sync()
          final key = '${orderDetail.id}_restore_${action.value}_${DateTime.now().millisecondsSinceEpoch}';
          await storage.addMessage(key, mostroMessage);

          // Update state using public method that calls updateWith internally
          final notifier = ref.read(orderNotifierProvider(orderDetail.id).notifier);
          notifier.updateStateFromMessage(mostroMessage);

          // If dispute exists, update state with dispute object using public method
          if (dispute != null) {
            notifier.updateDispute(dispute);
            _logger.i('Restore: added dispute to state for order ${orderDetail.id}');
          }

          _logger.i('Restore: built message for order ${orderDetail.id} with status ${orderDetail.status}, action $action');
        } catch (e, stack) {
          _logger.e('Restore: failed to process order ${orderDetail.id}', error: e, stackTrace: stack);
        }
      }

      _logger.i('Restore: state update completed for all orders');

      // Disable restore mode - back to normal message processing
      AbstractMostroNotifier.setRestoring(false);
      _logger.i('Restore: disabled restore mode - re-enabling message processing');

      // Navigate to home and clear notification tray
      final navProvider = ref.read(navigationProvider.notifier);
      navProvider.go('/');

      //While bulding subscriptions, some old notifications may have arrived - clear them all
      final notifProvider = ref.read(notificationActionsProvider.notifier);
      notifProvider.clearAll();

      _logger.i('Restore: navigated to home and cleared notification tray');

    } catch (e, stack) {
      // Ensure flag is cleared even on error
      AbstractMostroNotifier.setRestoring(false);
      _logger.e('Restore: error during restore', error: e, stackTrace: stack);
      rethrow;
    }
  }

  //Workflow:
  // 1. Clear existing data
  // 2. Create temporary subscription to key index 1 for restore notifications
  // 3. Send restore request and wait for response (Stage 1: GettingRestoreData)
  // 4. Process restore data and request order details (Stage 2: GettingOrdersDetails)
  // 5. Request last trade index (Stage 3: GettingTradeIndex)
  // 6. Complete restore process
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
      progress.updateStep(RestoreStep.requesting);
      await _sendRestoreRequest();
      final restoreDataEvent = await _waitForEvent(RestoreStage.gettingRestoreData);
      final extracted = await _extractRestoreData(restoreDataEvent);
      final ordersIds = extracted.orderIds;
      final disputes = extracted.disputes;
      progress.setOrdersReceived(ordersIds.length);

      if (ordersIds.isEmpty) {
        _logger.w('Restore: no orders or disputes to restore');
        await _sendLastTradeIndexRequest();
        final lastTradeIndexEvent = await _waitForEvent(RestoreStage.gettingTradeIndex);
        final lastTradeIndexResponse = await _extractLastTradeIndex(lastTradeIndexEvent);
        final lastTradeIndex = lastTradeIndexResponse.tradeIndex;
        await keyManager.setCurrentKeyIndex(lastTradeIndex + 1);
        progress.completeRestore();
        return;
      }

      // STAGE 2: Getting Orders Details
      progress.updateStep(RestoreStep.loadingDetails);
      final orderIdsList = ordersIds.keys.toList();
      _logger.i('Restore: requesting details for ${orderIdsList.length} orders: $orderIdsList');
      await _sendOrdersDetailsRequest(orderIdsList);
      final ordersDetailsEvent = await _waitForEvent(RestoreStage.gettingOrdersDetails);
      final ordersResponse = await _extractOrdersDetails(ordersDetailsEvent);

      // STAGE 3: Getting Last Trade Index
      await _sendLastTradeIndexRequest();
      final lastTradeIndexEvent = await _waitForEvent(RestoreStage.gettingTradeIndex);
      final lastTradeIndexResponse = await _extractLastTradeIndex(lastTradeIndexEvent);
      final lastTradeIndex = lastTradeIndexResponse.tradeIndex;

      // IMPORTANT: Cancel temporary subscription before proceeding to avoid interference
      await _tempSubscription?.cancel();
      _tempSubscription = null;

      // STAGE 4: Processing and restoring sessions
      progress.updateStep(RestoreStep.processingRoles);
      await restore(ordersIds, lastTradeIndex, ordersResponse, disputes);
    } catch (e, stack) {
      _logger.e('Restore: error during restore process', error: e, stackTrace: stack);
      ref.read(restoreProgressProvider.notifier).showError('');
    } finally {
      // Cleanup: always cancel subscription
      _logger.i('Restore: cleaning up subscription');
      await _tempSubscription?.cancel();
      _tempSubscription = null;
      _currentCompleter = null;

      // Only call completeRestore if not in error state
      final currentState = ref.read(restoreProgressProvider);
      if (currentState.step != RestoreStep.error) {
        ref.read(restoreProgressProvider.notifier).completeRestore();
      }
    }
  }
}

final restoreServiceProvider = Provider<RestoreService>((ref) {
  return RestoreService(ref);
});