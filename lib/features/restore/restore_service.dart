import 'dart:async';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/restore/restore_progress_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/features/restore/order_restorer.dart';
import 'package:mostro_mobile/features/restore/restore_message_handler.dart';
import 'package:mostro_mobile/features/restore/session_restorer.dart';
import 'package:mostro_mobile/shared/providers/local_notifications_providers.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/notifications_history_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';

class RestoreService {
  final Ref ref;
  final Logger _logger = Logger();

  late final RestoreMessageHandler _messageHandler;
  late final SessionRestorer _sessionRestorer;
  late final OrderRestorer _orderRestorer;

  StreamSubscription<NostrEvent>? _subscription;
  NostrKeyPairs? _tempTradeKey;
  final Set<String> _processedEventIds = {};

  _RestoreData? _data;

  RestoreService(this.ref) {
    _messageHandler = RestoreMessageHandler();
    _sessionRestorer = SessionRestorer(ref);
    _orderRestorer = OrderRestorer();
  }

  Future<void> importMnemonicAndRestore(String mnemonic) async {
    _logger.i('Restore: importing mnemonic');
    final keyManager = ref.read(keyManagerProvider);
    await keyManager.importMnemonic(mnemonic);
    await restore();
  }

  Future<void> restore() async {
    _logger.i('Restore: initiated');

    await _clearAll();
    _reset();

    final progress = ref.read(restoreProgressProvider.notifier);
    progress.startRestore();

    try {
      await _validatePrerequisites();
      await _setupSubscription();
      await _sendRestoreRequest();
    } catch (e, stackTrace) {
      _logger.e('Restore: failed', error: e, stackTrace: stackTrace);
      progress.showError(e.toString());
      rethrow;
    }
  }

  Future<void> _validatePrerequisites() async {
    final keyManager = ref.read(keyManagerProvider);
    if (keyManager.masterKeyPair == null) {
      throw Exception('Master key not found');
    }

    final settings = ref.read(settingsProvider);
    if (settings.mostroPublicKey.isEmpty) {
      throw Exception('Mostro not configured');
    }
  }

  Future<void> _setupSubscription() async {
    final keyManager = ref.read(keyManagerProvider);
    _tempTradeKey = await keyManager.deriveTradeKeyFromIndex(0);

    final filter = NostrFilter(
      kinds: [1059],
      p: [_tempTradeKey!.public],
      limit: 1,
    );

    final request = NostrRequest(filters: [filter]);
    final stream = ref.read(nostrServiceProvider).subscribeToEvents(request);

    _subscription = stream.listen(
      _handleEvent,
      onError: (error, stackTrace) {
        _logger.e('Restore: subscription error', error: error, stackTrace: stackTrace);
      },
      cancelOnError: false,
    );
  }

  Future<void> _sendRestoreRequest() async {
    final keyManager = ref.read(keyManagerProvider);
    final settings = ref.read(settingsProvider);

    final request = await _messageHandler.createRestoreRequest(
      tradeKey: _tempTradeKey!,
      masterKey: keyManager.masterKeyPair!,
      mostroPubkey: settings.mostroPublicKey,
    );

    await ref.read(nostrServiceProvider).publishEvent(request);
    _logger.d('Restore: request sent');
  }

  Future<void> _handleEvent(NostrEvent event) async {
    if (!_processedEventIds.add(event.id!)) return;

    final message = await _messageHandler.unwrapAndDecode(event, _tempTradeKey!);
    if (message == null) return;

    final order = message['order'] as Map<String, dynamic>?;
    final restore = message['restore'] as Map<String, dynamic>?;

    final action = (order ?? restore)?['action'] as String?;
    final payload = (order ?? restore)?['payload'];
    final data = order ?? restore;

    await _processAction(action, payload, data: data);
  }

  Future<void> _processAction(String? action, dynamic payload, {dynamic data}) async {
    if (action == null) return;

    _data ??= _RestoreData();

    switch (action) {
      case 'restore-session':
        if (_data!.hasRestoreData) return;
        _logger.d('Restore: processing session data');
        await _handleRestoreSession(payload);
        break;

      case 'orders':
        if (_data!.hasOrdersInfo) return;
        _logger.d('Restore: processing order details');
        _data!.orderDetails = (payload?['orders'] as List?)?.cast<Map<String, dynamic>>();
        _data!.hasOrdersInfo = true;
        _checkCompletion();
        break;

      case 'last-trade-index':
        if (_data!.hasTradeIndex) return;
        _logger.d('Restore: processing trade index');
        _data!.lastTradeIndex = data?['trade_index'] as int?;
        _data!.hasTradeIndex = true;
        _checkCompletion();
        break;

      default:
        _logger.w('Restore: unknown action "$action"');
    }
  }

  Future<void> _handleRestoreSession(dynamic payload) async {
    final restoreData = payload?['restore_data'];
    if (restoreData == null) return;

    _data!.restoreOrders = (restoreData['orders'] as List?)?.cast<Map<String, dynamic>>();
    _data!.restoreDisputes = (restoreData['disputes'] as List?)?.cast<Map<String, dynamic>>();
    _data!.hasRestoreData = true;

    final orderIds = _orderRestorer.extractOrderIds(
      restoreOrders: _data!.restoreOrders,
      restoreDisputes: _data!.restoreDisputes,
    );

    if (orderIds.isNotEmpty) {
      await _requestOrderDetails(orderIds);
    } else {
      _data!.hasOrdersInfo = true;
    }

    await _requestLastTradeIndex();
  }

  Future<void> _requestOrderDetails(List<String> orderIds) async {
    final keyManager = ref.read(keyManagerProvider);
    final settings = ref.read(settingsProvider);

    final request = await _messageHandler.createOrderDetailsRequest(
      tradeKey: _tempTradeKey!,
      masterKey: keyManager.masterKeyPair!,
      mostroPubkey: settings.mostroPublicKey,
      orderIds: orderIds,
    );

    await ref.read(nostrServiceProvider).publishEvent(request);
  }

  Future<void> _requestLastTradeIndex() async {
    final keyManager = ref.read(keyManagerProvider);
    final settings = ref.read(settingsProvider);

    final request = await _messageHandler.createLastTradeIndexRequest(
      tradeKey: _tempTradeKey!,
      masterKey: keyManager.masterKeyPair!,
      mostroPubkey: settings.mostroPublicKey,
    );

    await ref.read(nostrServiceProvider).publishEvent(request);
  }

  void _checkCompletion() {
    if (_data!.isComplete) {
      _finalize();
    }
  }

  Future<void> _finalize() async {
    try {
      await _sessionRestorer.cleanupTempSession(_tempTradeKey!.public);

      if (_data!.lastTradeIndex != null) {
        await _sessionRestorer.updateKeyIndex(_data!.lastTradeIndex!);
      }

      _orderRestorer.logOrderDetails(_data!.orderDetails);

      await _sessionRestorer.restoreSessions(
        restoreOrders: _data!.restoreOrders,
        restoreDisputes: _data!.restoreDisputes,
        orderDetails: _data!.orderDetails,
      );

      ref.invalidate(subscriptionManagerProvider);
      _logger.i('Restore: completed successfully');
    } catch (e, stackTrace) {
      _logger.e('Restore: finalization error', error: e, stackTrace: stackTrace);
    } finally {
      _cleanup();
    }
  }

  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    _tempTradeKey = null;
    _processedEventIds.clear();
    _data = null;

    final progress = ref.read(restoreProgressProvider.notifier);
    progress.completeRestore();
  }

  void _reset() {
    _processedEventIds.clear();
    _data = null;
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
}

class _RestoreData {
  List<Map<String, dynamic>>? restoreOrders;
  List<Map<String, dynamic>>? restoreDisputes;
  List<Map<String, dynamic>>? orderDetails;
  int? lastTradeIndex;

  bool hasRestoreData = false;
  bool hasOrdersInfo = false;
  bool hasTradeIndex = false;

  bool get isComplete => hasRestoreData && hasOrdersInfo && hasTradeIndex;
}

final restoreServiceProvider = Provider<RestoreService>((ref) {
  return RestoreService(ref);
});
