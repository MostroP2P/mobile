import 'dart:async';
import 'dart:convert';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/restore_message.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/notifications_history_repository_provider.dart'
    show notificationsRepositoryProvider;
import 'package:mostro_mobile/shared/providers/local_notifications_providers.dart';
import 'package:mostro_mobile/features/restore/restore_progress_notifier.dart';

class RestoreService {
  final Ref ref;
  final Logger _logger = Logger();

  // Temporary variables for restore process
  StreamSubscription<NostrEvent>? _tempSubscription;
  NostrKeyPairs? _tempTradeKey1;
  final Set<String> _processedEventIds = {};
  List<dynamic>? _tempRestoreOrders;
  List<dynamic>? _tempRestoreDisputes;
  List<dynamic>? _tempOrdersDetails;
  int? _tempLastTradeIndex;

  // Flags to track received data
  bool _receivedRestoreData = false;
  bool _receivedOrdersInfo = false;
  bool _receivedLastTradeIndex = false;

  RestoreService(this.ref);

  Future<void> importMnemonicAndRestore(String mnemonic) async {
    _logger.i('Importing mnemonic and restoring session');

    final keyManager = ref.read(keyManagerProvider);
    await keyManager.importMnemonic(mnemonic);

    await restore();
  }

  Future<void> restore() async {
    _logger.i('Starting restore session');

    // Clear existing data
    await _clearAll();
    _processedEventIds.clear();
    _receivedRestoreData = false;
    _receivedOrdersInfo = false;
    _receivedLastTradeIndex = false;
    _tempRestoreOrders = null;
    _tempRestoreDisputes = null;
    _tempOrdersDetails = null;
    _tempLastTradeIndex = null;

    final progressNotifier = ref.read(restoreProgressProvider.notifier);
    progressNotifier.startRestore();

    try {
      final keyManager = ref.read(keyManagerProvider);
      final masterKey = keyManager.masterKeyPair;

      if (masterKey == null) {
        progressNotifier.showError('No master key found');
        throw Exception('No master key found');
      }

      final settings = ref.read(settingsProvider);
      if (settings.mostroPublicKey.isEmpty) {
        progressNotifier.showError('Mostro not configured');
        throw Exception('Mostro public key not configured');
      }

      // Derive temporary trade key
      _tempTradeKey1 = await keyManager.deriveTradeKeyFromIndex(0);
      final filter = NostrFilter(
        kinds: [1059],
        p: [_tempTradeKey1!.public],
        limit: 1,
      );
      final request = NostrRequest(filters: [filter]);

      _tempSubscription = ref
          .read(nostrServiceProvider)
          .subscribeToEvents(request)
          .listen(
            _handleTempEvent,
            onError: (error, stackTrace) {
              _logger.e('Subscription error', error: error, stackTrace: stackTrace);
            },
            cancelOnError: false,
          );

      final restoreMessage = RestoreMessage();
      final rumor = NostrEvent.fromPartialData(
        keyPairs: _tempTradeKey1!,
        content: restoreMessage.toJsonString(),
        kind: 1,
        tags: [],
      );

      final wrappedEvent = await rumor.mostroWrapWithSeparateKeys(
        rumorKeys: _tempTradeKey1!,
        sealKeys: masterKey,
        receiverPubkey: settings.mostroPublicKey,
      );

      await ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
      _logger.i('Restore request sent');
    } catch (e) {
      _logger.e('Restore failed: $e');
      progressNotifier.showError(e.toString());
      rethrow;
    }
  }

  Future<void> _handleTempEvent(NostrEvent event) async {
    if (!_processedEventIds.add(event.id!)) {
      return;
    }

    try {
      final unwrapped = await event.mostroUnWrap(_tempTradeKey1!);

      if (unwrapped.content == null || unwrapped.content!.isEmpty) {
        return;
      }

      final content = jsonDecode(unwrapped.content!);

      if (content is! List || content.isEmpty) {
        return;
      }

      final order = content[0]['order'];
      final restore = content[0]['restore'];

      if (order != null) {
        await _processAction(order['action'] as String?, order['payload'], data: order);
      } else if (restore != null) {
        await _processAction(restore['action'] as String?, restore['payload'], data: restore);
      }
    } catch (e, stackTrace) {
      _logger.e('Error handling event', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _processAction(String? action, dynamic payload, {dynamic data}) async {
    if (action == null) {
      return;
    }

    switch (action) {
      case 'restore-session':
        if (_receivedRestoreData) {
          return;
        }
        _logger.i('Processing restore session data');
        _receivedRestoreData = true;
        if (payload != null) {
          await _handleRestoreData(payload);
        }
        break;

      case 'orders':
        if (_receivedOrdersInfo) {
          return;
        }
        _logger.i('Processing orders info');
        _receivedOrdersInfo = true;
        if (payload != null && payload['orders'] != null) {
          _tempOrdersDetails = payload['orders'] as List;
        }
        _checkAndCleanupIfComplete();
        break;

      case 'last-trade-index':
        if (_receivedLastTradeIndex) {
          return;
        }
        _logger.i('Processing last trade index');
        _receivedLastTradeIndex = true;
        if (data != null) {
          _tempLastTradeIndex = data['trade_index'] as int?;
        }
        _checkAndCleanupIfComplete();
        break;

      default:
        _logger.w('Unknown action: $action');
    }
  }

  Future<void> _handleRestoreData(dynamic payload) async {
    try {
      final restoreData = payload['restore_data'];
      if (restoreData == null) {
        return;
      }

      _tempRestoreOrders = restoreData['orders'] as List?;
      _tempRestoreDisputes = restoreData['disputes'] as List?;

      final List<String> orderIds = [];

      if (_tempRestoreOrders != null) {
        for (final order in _tempRestoreOrders!) {
          final orderId = order['order_id'] as String?;
          if (orderId != null) {
            orderIds.add(orderId);
          }
        }
      }

      if (_tempRestoreDisputes != null) {
        for (final dispute in _tempRestoreDisputes!) {
          final orderId = dispute['order_id'] as String?;
          if (orderId != null) {
            orderIds.add(orderId);
          }
        }
      }

      if (orderIds.isNotEmpty) {
        await _requestOrderDetails(orderIds);
      } else {
        _receivedOrdersInfo = true;
      }

      await _requestLastTradeIndex();
    } catch (e) {
      _logger.e('Error handling restore data: $e');
    }
  }

  Future<void> _requestOrderDetails(List<String> orderIds) async {
    final keyManager = ref.read(keyManagerProvider);
    final settings = ref.read(settingsProvider);
    final masterKey = keyManager.masterKeyPair!;

    final requestMessage = {
      'order': {
        'version': 1,
        'action': 'orders',
        'payload': {'ids': orderIds}
      }
    };

    final rumor = NostrEvent.fromPartialData(
      keyPairs: _tempTradeKey1!,
      content: jsonEncode([requestMessage, null]),
      kind: 1,
      tags: [],
    );

    final wrappedEvent = await rumor.mostroWrapWithSeparateKeys(
      rumorKeys: _tempTradeKey1!,
      sealKeys: masterKey,
      receiverPubkey: settings.mostroPublicKey,
    );

    await ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
  }

  Future<void> _requestLastTradeIndex() async {
    final keyManager = ref.read(keyManagerProvider);
    final settings = ref.read(settingsProvider);
    final masterKey = keyManager.masterKeyPair!;

    final requestMessage = {
      'restore': {
        'version': 1,
        'action': 'last-trade-index',
        'payload': null
      }
    };

    final rumor = NostrEvent.fromPartialData(
      keyPairs: _tempTradeKey1!,
      content: jsonEncode([requestMessage, null]),
      kind: 1,
      tags: [],
    );

    final wrappedEvent = await rumor.mostroWrapWithSeparateKeys(
      rumorKeys: _tempTradeKey1!,
      sealKeys: masterKey,
      receiverPubkey: settings.mostroPublicKey,
    );

    await ref.read(nostrServiceProvider).publishEvent(wrappedEvent);
  }

  void _checkAndCleanupIfComplete() {
    if (_receivedRestoreData && _receivedOrdersInfo && _receivedLastTradeIndex) {
      _processAllData();
    }
  }

  Future<void> _processAllData() async {
    try {
      final keyManager = ref.read(keyManagerProvider);
      final sessionNotifier = ref.read(sessionNotifierProvider.notifier);

      final tempSession = sessionNotifier.getSessionByTradeKey(_tempTradeKey1!.public);
      if (tempSession != null && tempSession.orderId != null) {
        await sessionNotifier.deleteSession(tempSession.orderId!);
        _logger.i('Deleted temporary session');
      }

      if (_tempLastTradeIndex != null) {
        await keyManager.setCurrentKeyIndex(_tempLastTradeIndex! + 1);
        _logger.i('Updated key index to: ${_tempLastTradeIndex! + 1}');
      }

      if (_tempOrdersDetails != null) {
        _logger.i('=== RESTORED ORDERS ===');
        for (final orderData in _tempOrdersDetails!) {
          _logger.i('Order data: $orderData');
        }
        _logger.i('Total orders: ${_tempOrdersDetails!.length}');
      }
      _cleanupTempSession();
    } catch (e) {
      _logger.e('Error processing all data: $e');
      _cleanupTempSession();
    }
  }

  void _cleanupTempSession() {
    _tempSubscription?.cancel();
    _tempSubscription = null;
    _tempTradeKey1 = null;
    _processedEventIds.clear();

    _receivedRestoreData = false;
    _receivedOrdersInfo = false;
    _receivedLastTradeIndex = false;

    _tempRestoreOrders = null;
    _tempRestoreDisputes = null;
    _tempOrdersDetails = null;
    _tempLastTradeIndex = null;

    final progressNotifier = ref.read(restoreProgressProvider.notifier);
    progressNotifier.completeRestore();

    _logger.i('Restore completed');
  }

  Future<void> _clearAll() async {
    try {
      final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
      await sessionNotifier.reset();

      final mostroStorage = ref.read(mostroStorageProvider);
      await mostroStorage.deleteAll();

      final notificationsRepo = ref.read(notificationsRepositoryProvider);
      await notificationsRepo.clearAll();

      final localNotifications = ref.read(localNotificationsProvider);
      await localNotifications.cancelAll();
    } catch (e) {
      _logger.w('Error clearing data: $e');
    }
  }
}

final restoreServiceProvider = Provider<RestoreService>((ref) {
  return RestoreService(ref);
});