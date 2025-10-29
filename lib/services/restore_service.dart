import 'dart:async';
import 'dart:convert';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/restore_data.dart';
import 'package:mostro_mobile/data/models/restore_message.dart';
import 'package:mostro_mobile/data/models/orders_request_message.dart';
import 'package:mostro_mobile/data/models/last_trade_index_message.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/notifications_history_repository_provider.dart'
    show notificationsRepositoryProvider;
import 'package:mostro_mobile/shared/providers/local_notifications_providers.dart';
import 'package:mostro_mobile/features/restore/restore_progress_notifier.dart';
import 'package:mostro_mobile/features/restore/restore_progress_state.dart';

class RestoreService {
  final Ref ref;
  final Logger _logger = Logger();

  // Temporary subscription for restore operations using trade key 1
  StreamSubscription<NostrEvent>? _tempSubscription;
  NostrKeyPairs? _tempTradeKey1;
  final Set<String> _processedEventIds = {}; // In-memory deduplication

  RestoreService(this.ref);

  Future<void> importMnemonicAndRestore(String mnemonic) async {
    _logger.i('Importing mnemonic and restoring session');

    final keyManager = ref.read(keyManagerProvider);
    await keyManager.importMnemonic(mnemonic);

    await restore();
  }

  Future<void> restore() async {
    await _clearAll();
    _processedEventIds.clear();

    _logger.i('Starting restore session');

    // Show overlay
    final progressNotifier = ref.read(restoreProgressProvider.notifier);
    progressNotifier.startRestore();

    try {
      final keyManager = ref.read(keyManagerProvider);
      final masterKey = keyManager.masterKeyPair;

      if (masterKey == null) {
        _logger.w('Cannot restore: no master key found');
        progressNotifier.showError('No master key found');
        throw Exception('No master key found');
      }

      final settings = ref.read(settingsProvider);
      if (settings.mostroPublicKey.isEmpty) {
        _logger.w('Cannot restore: Mostro public key not configured');
        progressNotifier.showError('Mostro not configured');
        throw Exception('Mostro public key not configured');
      }

      // Derive trade key 1 for temporary subscription
      _tempTradeKey1 = await keyManager.deriveTradeKeyFromIndex(1);
      _logger.i('Derived trade key 1: ${_tempTradeKey1!.public}');

      // Subscribe to trade key 1 with since filter (no historical events)
      final filter = NostrFilter(
        kinds: [1059],
        p: [_tempTradeKey1!.public],
        since: DateTime.now(),
      );
      final request = NostrRequest(filters: [filter]);

      _tempSubscription = ref
          .read(nostrServiceProvider)
          .subscribeToEvents(request)
          .listen(
            _handleTempEvent,
            onError: (error, stackTrace) {
              _logger.e('Temp subscription error',
                  error: error, stackTrace: stackTrace);
            },
            cancelOnError: false,
          );

      _logger.i('Temp subscription created for trade key 1');

      // Prepare restore request
      final restoreMessage = RestoreMessage();
      final rumor = NostrEvent.fromPartialData(
        keyPairs: _tempTradeKey1!,
        content: restoreMessage.toJsonString(),
        kind: 1,
        tags: [],
      );

      _logger.i(
          'Rumor created with trade key 1, wrapping with seal=${masterKey.public}, receiver=${settings.mostroPublicKey}');

      // Wrap with separate keys: seal=master, rumor=trade key 1
      final wrappedEvent = await rumor.mostroWrapWithSeparateKeys(
        rumorKeys: _tempTradeKey1!,
        sealKeys: masterKey,
        receiverPubkey: settings.mostroPublicKey,
      );

      _logger.i('Wrapped event created, publishing to relays');
      await ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
      _logger.i('Restore request sent');
    } catch (e) {
      _logger.e('Restore failed: $e');
      progressNotifier.showError(e.toString());
      rethrow;
    }
  }

  Future<void> processRestoreData(Map<String, dynamic> payload) async {
    final progressNotifier = ref.read(restoreProgressProvider.notifier);

    try {
      final restoreData = RestoreData.fromJson(payload);
      final sessionNotifier = ref.read(sessionNotifierProvider.notifier);

      final totalOrders = restoreData.orders.length + restoreData.disputes.length;
      _logger.i('Processing $totalOrders orders (${restoreData.orders.length} orders, ${restoreData.disputes.length} disputes)');

      // Update overlay to receiving orders
      progressNotifier.setOrdersReceived(totalOrders);

      final keyManager = ref.read(keyManagerProvider);
      final settings = ref.read(settingsProvider);

      final List<String> orderIds = [];
      final masterKey = keyManager.masterKeyPair!;

      // Process orders
      for (final order in restoreData.orders) {
        final tradeKey = await keyManager.deriveTradeKeyFromIndex(order.tradeIndex);

        final session = Session(
          masterKey: masterKey,
          tradeKey: tradeKey,
          keyIndex: order.tradeIndex,
          fullPrivacy: settings.fullPrivacyMode,
          startTime: DateTime.now(),
          orderId: order.id,
        );

        await sessionNotifier.saveSession(session);
        orderIds.add(order.id);
        progressNotifier.incrementProgress();
      }

      // Process disputes
      for (final dispute in restoreData.disputes) {
        final tradeKey = await keyManager.deriveTradeKeyFromIndex(dispute.tradeIndex);

        final session = Session(
          masterKey: masterKey,
          tradeKey: tradeKey,
          keyIndex: dispute.tradeIndex,
          fullPrivacy: settings.fullPrivacyMode,
          startTime: DateTime.now(),
          orderId: dispute.orderId,
        );

        await sessionNotifier.saveSession(session);
        orderIds.add(dispute.orderId);
        progressNotifier.incrementProgress();
      }

      // Request order details
      if (orderIds.isNotEmpty) {
        progressNotifier.updateStep(RestoreStep.loadingDetails, total: orderIds.length);
        await _requestOrderDetails(orderIds, masterKey, settings.mostroPublicKey);
      } else {
        // No orders to restore, request last trade index directly
        await _requestLastTradeIndex();
      }
    } catch (e) {
      _logger.e('Process restore data failed: $e');
      progressNotifier.showError(e.toString());
      rethrow;
    }
  }

  Future<void> _requestOrderDetails(
    List<String> orderIds,
    NostrKeyPairs masterKey,
    String mostroPublicKey,
  ) async {
    final requestId = DateTime.now().millisecondsSinceEpoch;
    final ordersRequest = OrdersRequestMessage(
      requestId: requestId,
      orderIds: orderIds,
    );

    final rumor = NostrEvent.fromPartialData(
      keyPairs: _tempTradeKey1!,
      content: ordersRequest.toJsonString(),
      kind: 1,
      tags: [],
    );

    final wrappedEvent = await rumor.mostroWrapWithSeparateKeys(
      rumorKeys: _tempTradeKey1!,
      sealKeys: masterKey,
      receiverPubkey: mostroPublicKey,
    );

    await ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
    _logger.i('Requested details for ${orderIds.length} orders with trade key 1');
  }

  Future<void> processOrderDetails(List<dynamic> ordersData) async {
    final sessionNotifier = ref.read(sessionNotifierProvider.notifier);

    for (final orderData in ordersData) {
      final orderId = orderData['id'] as String?;
      final buyerPubkey = orderData['buyer_trade_pubkey'] as String?;
      final sellerPubkey = orderData['seller_trade_pubkey'] as String?;

      if (orderId == null) continue;

      final session = sessionNotifier.getSessionByOrderId(orderId);
      if (session == null) continue;

      if (buyerPubkey != null && session.tradeKey.public == buyerPubkey) {
        await sessionNotifier.updateSession(orderId, (s) => s.role = Role.buyer);
      } else if (sellerPubkey != null && session.tradeKey.public == sellerPubkey) {
        await sessionNotifier.updateSession(orderId, (s) => s.role = Role.seller);
      }
    }

    _logger.i('Updated session roles for ${ordersData.length} orders');
  }

  Future<void> _requestLastTradeIndex() async {
    final keyManager = ref.read(keyManagerProvider);
    final masterKey = keyManager.masterKeyPair!;
    final settings = ref.read(settingsProvider);

    final request = LastTradeIndexRequest();

    final rumor = NostrEvent.fromPartialData(
      keyPairs: _tempTradeKey1!,
      content: request.toJsonString(),
      kind: 1,
      tags: [],
    );

    final wrappedEvent = await rumor.mostroWrapWithSeparateKeys(
      rumorKeys: _tempTradeKey1!,
      sealKeys: masterKey,
      receiverPubkey: settings.mostroPublicKey,
    );

    await ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
    _logger.i('Requested last trade index with trade key 1');

    // Update progress
    final progressNotifier = ref.read(restoreProgressProvider.notifier);
    progressNotifier.updateStep(RestoreStep.finalizing);
  }

  Future<void> _handleTempEvent(NostrEvent event) async {
    _logger.i('Received temp event: ${event.id}');

    // In-memory deduplication
    if (!_processedEventIds.add(event.id!)) {
      _logger.d('Skipping duplicate temp event: ${event.id}');
      return;
    }

    try {
      // Unwrap with trade key 1
      final unwrapped = await event.unWrap(_tempTradeKey1!.private);

      if (unwrapped.content == null || unwrapped.content!.isEmpty) {
        _logger.w('Empty content in temp event');
        return;
      }

      final content = jsonDecode(unwrapped.content!);

      if (content is! List || content.isEmpty) {
        _logger.w('Invalid content format in temp event');
        return;
      }

      final order = content[0]['order'];
      if (order == null) {
        _logger.w('No order field in temp event');
        return;
      }

      final action = order['action'] as String?;
      final payload = order['payload'];

      _logger.i('Processing temp event with action: $action');

      // Route based on action
      switch (action) {
        case 'restore-data':
          if (payload != null) {
            await processRestoreData(payload);
          }
          break;
        case 'orders-info':
          if (payload != null && payload is List) {
            await processOrderDetails(payload);
            // After details, request last trade index
            await _requestLastTradeIndex();
          }
          break;
        case 'last-trade-index':
          if (payload != null) {
            final index = payload['index'] as int?;
            if (index != null) {
              final keyManager = ref.read(keyManagerProvider);
              await keyManager.setCurrentKeyIndex(index + 1);
              _logger.i('Updated key index to: ${index + 1}');
            }
          }
          // Finish restore after index received
          await _finishRestore();
          break;
        default:
          _logger.w('Unknown action in temp event: $action');
      }
    } catch (e, stackTrace) {
      _logger.e('Error handling temp event', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _finishRestore() async {
    _logger.i('Finishing restore - cleaning up temp subscription');

    // Cancel temp subscription
    await _tempSubscription?.cancel();
    _tempSubscription = null;
    _tempTradeKey1 = null;
    _processedEventIds.clear();

    // Complete restore progress overlay
    final progressNotifier = ref.read(restoreProgressProvider.notifier);
    progressNotifier.completeRestore();

    _logger.i('Restore completed successfully');
  }

  Future<void> _clearAll() async {
    try {
      // Clean existing sessions, orders, notifications and events before processing restore data
      final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
      await sessionNotifier.reset();

      final mostroStorage = ref.read(mostroStorageProvider);
      await mostroStorage.deleteAll();


      final notificationsRepo = ref.read(notificationsRepositoryProvider);
      await notificationsRepo.clearAll();

      final localNotifications = ref.read(localNotificationsProvider);
      await localNotifications.cancelAll();

      _logger.i('Cleared all data (preserved admin event history)');
    } catch (e) {
      _logger.w('Error clearing data: $e');
    }
  }
}

final restoreServiceProvider = Provider<RestoreService>((ref) {
  return RestoreService(ref);
});