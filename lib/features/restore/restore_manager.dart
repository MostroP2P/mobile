import 'dart:async';
import 'dart:convert';
import 'package:dart_nostr/nostr/core/key_pairs.dart';
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
import 'package:mostro_mobile/features/restore/restore_mode_provider.dart';
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
  NostrKeyPairs? _tempTradeKey; // Temporary trade key (index 1) used during restore process
  NostrKeyPairs? _masterKey; // Master key pair used during restore process

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

    // Get the new instance and initialize it
    final newKeyManager = ref.read(keyManagerProvider);
    await newKeyManager.init();

    await initRestoreProcess();
  }

  Future<void> _clearAll() async {
    try {
      _logger.i('Restore: clearing all existing data before restore');
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
    // Check if event matches current stage criteria
    if (_currentCompleter != null && !_currentCompleter!.isCompleted) {
      _currentCompleter!.complete(event);
    }
  }

  Future<StreamSubscription<NostrEvent>> _createTempSubscription() async {
    //use temporary trade key 1 to subscribe to restore notifications
    if (_tempTradeKey == null) {
      throw Exception('Temp trade key not initialized');
    }

    final filter = NostrFilter(
      kinds: [1059],
      p: [_tempTradeKey!.public],
      limit: 0, //IMPORTANT:  limit 0 indicates we don't want historical events, only new ones https://nostrbook.dev/protocol/filter
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
    _logger.i('Restore: sending restore data request');

    if (_tempTradeKey == null && _masterKey == null) {
      throw Exception('Temp trade key or master key not initialized');
    }

    final settings = ref.read(settingsProvider);

    // Create restore message with EmptyPayload as protocol spec
    final mostroMessage = MostroMessage<EmptyPayload>(
      action: Action.restore,
      payload: EmptyPayload(),
    );

    // Respect full privacy mode: if enabled, don't pass master key, wrap will be done just with trade key
    final wrappedEvent = await mostroMessage.wrap(
      tradeKey: _tempTradeKey!,
      recipientPubKey: settings.mostroPublicKey,
      masterKey: settings.fullPrivacyMode ? null : _masterKey
    );

    await ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
    _logger.i('Restore: request sent successfully');
  }
  
  //Extracts restore data, returns:
  // Orders map {orderId: tradeIndex}
  // List of disputes
  Future<({Map<String, int> ordersMap, List<RestoredDispute> disputes})> _extractRestoreData(NostrEvent event) async {
    try {
      if (_tempTradeKey == null) {
        throw Exception('Temp trade key not initialized');
      }

      // Unwrap the gift wrap (kind 1059) to get the rumor
      final rumor = await event.mostroUnWrap(_tempTradeKey!);

      if (rumor.content == null || rumor.content!.isEmpty) {
        throw Exception('Rumor content is empty');
      }

      final contentList = jsonDecode(rumor.content!) as List<dynamic>;
      final messageData = contentList[0] as Map<String, dynamic>;

      // Check if Mostro returned cant-do (not found)
      if (messageData.containsKey('cant-do')) {
        _logger.w('Restore: Mostro returned cant-do for restore data (no orders found)');
        return (ordersMap: <String, int>{}, disputes: <RestoredDispute>[]);
      }

      // Extract payload from restore wrapper
      final restoreWrapper = messageData['restore'] as Map<String, dynamic>?;

      if (restoreWrapper == null) {
        _logger.w('Restore: no restore wrapper found, returning empty orders');
        return (ordersMap: <String, int>{}, disputes: <RestoredDispute>[]);
      }

      final payload = restoreWrapper['payload'] as Map<String, dynamic>?;

      if (payload == null) {
        _logger.w('Restore: no payload found in restore wrapper, returning empty orders');
        return (ordersMap: <String, int>{}, disputes: <RestoredDispute>[]);
      }

      final restoreData = RestoreData.fromJson(payload);

      final Map<String, int> ordersMap = <String, int>{};

      for (var order in restoreData.orders) {
        ordersMap[order.id] = order.tradeIndex;
      }

      //Also orders with disputes must be included
      for (var dispute in restoreData.disputes) {
        ordersMap[dispute.orderId] = dispute.tradeIndex;
      }

      final List<RestoredDispute> disputesList = restoreData.disputes;

      return (ordersMap: ordersMap, disputes: disputesList);
    } catch (e, stack) {
      _logger.e('Restore: failed to extract restore data', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> _sendOrdersDetailsRequest(List<String> orderIds) async {
    _logger.i('Restore: sending orders details request for ${orderIds.length} orders');

    if (_tempTradeKey == null && _masterKey == null) {
      throw Exception('Temp trade key or master key not initialized');
    }

    final settings = ref.read(settingsProvider);

    final mostroMessage = MostroMessage<OrdersPayload>(
      action: Action.orders,
      requestId: DateTime.now().millisecondsSinceEpoch,
      payload: OrdersPayload(ids: orderIds),
    );

    // Respect full privacy mode: if enabled, don't pass master key, wrap will be done just with trade key
    final wrappedEvent = await mostroMessage.wrap(
      tradeKey: _tempTradeKey!,
      recipientPubKey: settings.mostroPublicKey,
      masterKey: settings.fullPrivacyMode ? null : _masterKey
    );

    await ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
    _logger.i('Restore: orders details request sent successfully');
  }

  //Extracts orders details from gift wrap event, returns OrdersResponse
  Future<OrdersResponse> _extractOrdersDetails(NostrEvent event) async {
    try {
      _logger.i('Restore: extracting orders details from gift wrap event ${event.id}');

      if (_tempTradeKey == null) {
        throw Exception('Temp trade key not initialized');
      }

      // Unwrap the gift wrap (kind 1059) to get the rumor
      final rumor = await event.mostroUnWrap(_tempTradeKey!);

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

      return ordersResponse;
    } catch (e, stack) {
      _logger.e('Restore: failed to extract orders details', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> _sendLastTradeIndexRequest() async {
    _logger.i('Restore: sending last trade index request');

    if (_tempTradeKey == null && _masterKey == null) {
      throw Exception('Temp trade key or master key not initialized');
    }

    final settings = ref.read(settingsProvider);

    // Create last-trade-index message with EmptyPayload as protocol spec
    final mostroMessage = MostroMessage<EmptyPayload>(
      action: Action.lastTradeIndex,
      payload: EmptyPayload(),
    );

    // Respect full privacy mode: if enabled, don't pass master key, wrap will be done just with trade key
    final wrappedEvent = await mostroMessage.wrap(
      tradeKey: _tempTradeKey!,
      recipientPubKey: settings.mostroPublicKey,
      masterKey: settings.fullPrivacyMode ? null : _masterKey
    );

    await ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
    _logger.i('Restore: last trade index request sent successfully');
  }

  Future<LastTradeIndexResponse> _extractLastTradeIndex(NostrEvent event) async {
    try {
      _logger.i('Restore: extracting last trade index from gift wrap event ${event.id}');

      if (_tempTradeKey == null) {
        throw Exception('Temp trade key not initialized');
      }

      final rumor = await event.mostroUnWrap(_tempTradeKey!);

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

  /// Determines if the user initiated the dispute with double verification
  ///
  /// Security checks:
  /// 1. Verify session belongs to this order (compare pubkeys based on role)
  /// 2. Compare trade_index to determine who initiated the dispute
  ///
  /// The dispute's trade_index indicates which party initiated it.
  /// If it matches the user's session trade_index, the user initiated the dispute.
  bool _determineIfUserInitiatedDispute({
    required RestoredDispute restoredDispute,
    required Session session,
    required Order order,
  }) {
    // Security verification: ensure session's trade pubkey matches order's pubkey for the role
    final sessionPubkey = session.tradeKey.public;
    final sessionRole = session.role;

    bool sessionMatchesOrder = false;
    if (sessionRole == Role.buyer && order.buyerTradePubkey == sessionPubkey) {
      sessionMatchesOrder = true;
    } else if (sessionRole == Role.seller && order.sellerTradePubkey == sessionPubkey) {
      sessionMatchesOrder = true;
    }

    if (!sessionMatchesOrder) {
      _logger.w(
        'Restore: session pubkey mismatch for order ${order.id} - '
        'session role: $sessionRole, session pubkey: $sessionPubkey, '
        'buyer pubkey: ${order.buyerTradePubkey}, seller pubkey: ${order.sellerTradePubkey}'
      );
      // Default to peer-initiated if we can't verify session belongs to order
      return false;
    }

    // Compare trade indexes: if dispute trade_index matches user's session trade_index,
    // then the user initiated the dispute
    final userInitiated = restoredDispute.tradeIndex == session.keyIndex;

    //TODO: Improve dispute initiation detection if protocol changes in future
    return userInitiated;
  }

  /// Maps Status to the appropriate Action for restored orders
  Action _getActionFromStatus(Status status, Role? userRole) {
    switch (status) {
      case Status.pending:
        return Action.newOrder;
      case Status.waitingBuyerInvoice:
        // If user is buyer, they need to add invoice
        // If user is seller, they are waiting for buyer to add invoice
        return userRole == Role.buyer
            ? Action.addInvoice
            : Action.waitingBuyerInvoice;
      case Status.waitingPayment:
        // If user is seller, they need to pay invoice
        // If user is buyer, they are waiting for seller to pay
        return userRole == Role.seller
            ? Action.payInvoice
            : Action.waitingSellerToPay;
      case Status.active:
        // If user is buyer, they need to confirm fiat sent
        // If user is seller, buyer took the order and seller waits
        return userRole == Role.buyer
            ? Action.fiatSent
            : Action.buyerTookOrder;
      case Status.fiatSent:
        // If user is seller, they need to release funds
        // If user is buyer, they are waiting for seller to release
        return userRole == Role.seller
            ? Action.release
            : Action.fiatSentOk;
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
      if (_masterKey == null) {
        throw Exception('Master key not initialized');
      }

      final keyManager = ref.read(keyManagerProvider);
      final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
      final progress = ref.read(restoreProgressProvider.notifier);
      final settings = ref.read(settingsProvider);

      // Set the next trade key index
      await keyManager.setCurrentKeyIndex(lastTradeIndex + 1);

      // Enable restore mode to block all old message processing
      ref.read(isRestoringProvider.notifier).state = true;
      _logger.i('Restore: enabled restore mode - blocking all old message processing');

      // Restore each a session to get future messages
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
        final userPubkey = tradeKey.public;

        if (orderDetail.buyerTradePubkey != null && orderDetail.buyerTradePubkey == userPubkey) {
          role = Role.buyer;
        } else if (orderDetail.sellerTradePubkey != null && orderDetail.sellerTradePubkey == userPubkey) {
          role = Role.seller;
        }

        final session = Session(
          masterKey: _masterKey!,
          tradeKey: tradeKey,
          keyIndex: tradeIndex,
          fullPrivacy: settings.fullPrivacyMode,
          startTime: DateTime.now(),
          orderId: orderDetail.id,
          role: role,
        );

        // Store session
        await sessionNotifier.saveSession(session);

        progress.incrementProgress();
      }

      // Wait for historical messages to arrive and be saved to storage
      _logger.i('Restore: waiting 8 seconds for historical messages to be saved...');
      //WARNING: It is very important to wait here to ensure all historical messages arrive before rebuilding state
      // Relays could send them with delay
      await Future.delayed(const Duration(seconds: 8));

      // Build MostroMessages from ordersResponse and update state (source of truth from Mostro)
      _logger.i('Restore: building messages for ${ordersResponse.orders.length} orders from ordersResponse');
      final storage = ref.read(mostroStorageProvider);

      // Process each order detail
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

            // We need the session to compare trade indexes
            bool userInitiated = false;
            if (session == null) {
              _logger.w('Restore: no session found for disputed order ${orderDetail.id}, defaulting to peer-initiated');
              action = Action.disputeInitiatedByPeer;
            } else {
              // Determine if user initiated with double verification TODO : improve if protocol changes
              userInitiated = _determineIfUserInitiatedDispute(
                restoredDispute: restoredDispute,
                session: session,
                order: order,
              );

              action = userInitiated
                  ? Action.disputeInitiatedByYou
                  : Action.disputeInitiatedByPeer;
            }

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

            _logger.i('Restore: dispute found for order ${orderDetail.id}');
          } else {
            // Regular order without dispute
            final session = ref.read(sessionNotifierProvider.notifier).getSessionByOrderId(orderDetail.id);
            action = _getActionFromStatus(order.status, session?.role);
          }

          // Build generic MostroMessage with Order payload
          // IMPORTAN : we need to create new message due to synchronization with stored messages
          final mostroMessage = MostroMessage<Order>(
            id: orderDetail.id,
            action: action,
            payload: order,
            timestamp: orderDetail.createdAt ?? DateTime.now().millisecondsSinceEpoch,
          );

          // Save message to storage
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
        } catch (e, stack) {
          _logger.e('Restore: failed to process order ${orderDetail.id}', error: e, stackTrace: stack);
        }
      }

      _logger.i('Restore: state update completed for all orders');

      // Disable restore mode - back to normal message processing
      ref.read(isRestoringProvider.notifier).state = false;
      _logger.i('Restore: disabled restore mode - re-enabling message processing');

    } catch (e, stack) {
      // Ensure flag is cleared even on error
      ref.read(isRestoringProvider.notifier).state = false;
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

      // Validate and initialize master key
      final keyManager = ref.read(keyManagerProvider);
      if (keyManager.masterKeyPair == null) {
        _logger.e('Restore: master key not found after import');
        throw Exception('Master key not found');
      }
      _masterKey = keyManager.masterKeyPair;
      _logger.i('Restore: initialized master key');

      // Validate Mostro public key
      final settings = ref.read(settingsProvider);
      if (settings.mostroPublicKey.isEmpty) {
        _logger.e('Restore: Mostro not configured');
        throw Exception('Mostro not configured');
      }

      // Initialize temporary trade key (index 1) for entire restore process
      _tempTradeKey = await keyManager.deriveTradeKeyFromIndex(1);
      _logger.i('Restore: initialized temp trade key with pubkey ${_tempTradeKey!.public}');

      // Subscribe to temporary notifications
      _tempSubscription = await _createTempSubscription();

      // STAGE 1: Getting Restore Data
      progress.updateStep(RestoreStep.requesting);
      await _sendRestoreRequest();
      final restoreDataEvent = await _waitForEvent(RestoreStage.gettingRestoreData);
      final extracted = await _extractRestoreData(restoreDataEvent);
      final ordersMap = extracted.ordersMap;
      final disputes = extracted.disputes;
      progress.setOrdersReceived(ordersMap.length);

      if (ordersMap.isEmpty) {
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
      final ordersIdsList = ordersMap.keys.toList();
      _logger.i('Restore: requesting details for ${ordersIdsList.length} orders: $ordersIdsList');
      await _sendOrdersDetailsRequest(ordersIdsList);
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
      await restore(ordersMap, lastTradeIndex, ordersResponse, disputes);

      // Navigate to home and clear notification tray
      final navProvider = ref.read(navigationProvider.notifier);
      navProvider.go('/');

      //While bulding subscriptions, some old notifications may have arrived - clear them all
      final notifProvider = ref.read(notificationActionsProvider.notifier);
      notifProvider.clearAll();

    } catch (e, stack) {
      _logger.e('Restore: error during restore process', error: e, stackTrace: stack);
      ref.read(restoreProgressProvider.notifier).showError('');
    } finally {
      // Cleanup: always cancel subscription and clear keys
      _logger.i('Restore: cleaning up subscription and keys');
      await _tempSubscription?.cancel();
      _tempSubscription = null;
      _currentCompleter = null;
      _tempTradeKey = null;
      _masterKey = null;

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