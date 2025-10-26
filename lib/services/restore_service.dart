import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/restore_data.dart';
import 'package:mostro_mobile/data/models/restore_message.dart';
import 'package:mostro_mobile/data/models/orders_request_message.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/services/last_trade_index_service.dart';
import 'package:mostro_mobile/shared/providers/notifications_history_repository_provider.dart'
    show notificationsRepositoryProvider;
import 'package:mostro_mobile/shared/providers/local_notifications_providers.dart';
import 'package:mostro_mobile/features/restore/restore_progress_notifier.dart';
import 'package:mostro_mobile/features/restore/restore_progress_state.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_type.dart';

class RestoreService {
  final Ref ref;
  final Logger _logger = Logger();

  RestoreService(this.ref);

  Future<void> importMnemonicAndRestore(String mnemonic) async {
    _logger.i('Importing mnemonic and restoring session');

    final keyManager = ref.read(keyManagerProvider);
    await keyManager.importMnemonic(mnemonic);

    // Update admin subscription after master key changes
    _logger.i('Master key imported, updating admin subscription');
    ref.read(subscriptionManagerProvider).updateAdminSubscription();

    await restore();
  }

  Future<void> restore() async {
    await _clearAll();

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

      // Ensure MostroService is initialized to receive admin messages
      ref.read(mostroServiceProvider);

      _logger.i('Preparing restore request with master key pubkey: ${masterKey.public}');

      final restoreMessage = RestoreMessage();
      final rumor = NostrEvent.fromPartialData(
        keyPairs: masterKey,
        content: restoreMessage.toJsonString(),
        kind: 1,
        tags: [],
      );

      _logger.i('Rumor created, wrapping with sender=${masterKey.public}, receiver=${settings.mostroPublicKey}');

      final wrappedEvent = await rumor.mostroWrap(
        masterKey,
        settings.mostroPublicKey,
      );

      _logger.i('Wrapped event created, publishing to relays');
      await ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
      _logger.i('Restore request sent');

      // Verify admin subscription is active
      final subManager = ref.read(subscriptionManagerProvider);
      final hasAdminSub = subManager.hasActiveSubscription(SubscriptionType.admin);
      final adminFilters = subManager.getActiveFilters(SubscriptionType.admin);
      _logger.i('Admin events subscription status after restore request: active=$hasAdminSub, filters=${adminFilters.map((f) => f.toMap()).toList()}');
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
      }

      // Finalize
      progressNotifier.updateStep(RestoreStep.finalizing);
      await ref.read(lastTradeIndexServiceProvider).requestLastTradeIndex();

      progressNotifier.completeRestore();
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
      keyPairs: masterKey,
      content: ordersRequest.toJsonString(),
      kind: 1,
      tags: [],
    );

    final wrappedEvent = await rumor.mostroWrap(
      masterKey,
      mostroPublicKey,
    );

    await ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
    _logger.i('Requested details for ${orderIds.length} orders');
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

  Future<void> _clearAll() async {
    try {
      // Clean existing sessions, orders, notifications and events before processing restore data
      final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
      await sessionNotifier.reset();

      final mostroStorage = ref.read(mostroStorageProvider);
      await mostroStorage.deleteAll();

      // Preserve admin events to prevent reprocessing historical restore messages
      final eventStorage = ref.read(eventStorageProvider);
      await eventStorage.deleteAllExceptAdmin();

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