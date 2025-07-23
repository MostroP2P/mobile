import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';

class MostroService {
  final Ref ref;
  final _logger = Logger();

  Settings _settings;
  StreamSubscription<NostrEvent>? _ordersSubscription;

  MostroService(this.ref) : _settings = ref.read(settingsProvider);

  void init() {
    // Subscribe to the orders stream from SubscriptionManager
    // The SubscriptionManager will automatically manage subscriptions based on SessionNotifier changes
    _ordersSubscription = ref.read(subscriptionManagerProvider).orders.listen(
      _onData,
      onError: (error, stackTrace) {
        _logger.e('Error in orders subscription',
            error: error, stackTrace: stackTrace);
      },
      cancelOnError: false,
    );
  }

  void dispose() {
    _ordersSubscription?.cancel();
    _logger.i('MostroService disposed');
  }

  Future<void> _onData(NostrEvent event) async {
    final eventStore = ref.read(eventStorageProvider);

    if (await eventStore.hasItem(event.id!)) return;
    await eventStore.putItem(
      event.id!,
      {
        'id': event.id,
        'created_at': event.createdAt!.millisecondsSinceEpoch ~/ 1000,
      },
    );

    final sessions = ref.read(sessionNotifierProvider);
    final matchingSession = sessions.firstWhereOrNull(
        (s) => s.tradeKey.public == event.recipient,
      );
    if (matchingSession == null) {
      _logger.w('No matching session found for recipient: ${event.recipient}');
      return;
    }
    final privateKey = matchingSession.tradeKey.private;

    try {
      final decryptedEvent = await event.unWrap(privateKey);
      if (decryptedEvent.content == null) return;

      final result = jsonDecode(decryptedEvent.content!);
      if (result is! List) return;

      final msg = MostroMessage.fromJson(result[0]);
      final messageStorage = ref.read(mostroStorageProvider);
      await messageStorage.addMessage(decryptedEvent.id!, msg);
      _logger.i(
        'Received DM, Event ID: ${decryptedEvent.id} with payload: ${decryptedEvent.content}',
      );
    } catch (e) {
      _logger.e('Error processing event', error: e);
    }
  }

  Future<void> submitOrder(MostroMessage order) async {
    await publishOrder(order);
  }

  Future<void> takeBuyOrder(String orderId, int? amount) async {
    final amt = amount != null ? Amount(amount: amount) : null;
    await publishOrder(
      MostroMessage(
        action: Action.takeBuy,
        id: orderId,
        payload: amt,
      ),
    );
  }

  Future<void> takeSellOrder(
      String orderId, int? amount, String? lnAddress) async {
    final payload = lnAddress != null
        ? PaymentRequest(
            order: null,
            lnInvoice: lnAddress,
            amount: amount,
          )
        : amount != null
            ? Amount(amount: amount)
            : null;

    await publishOrder(
      MostroMessage(
        action: Action.takeSell,
        id: orderId,
        payload: payload,
      ),
    );
  }

  Future<void> sendInvoice(String orderId, String invoice, int? amount) async {
    final payload = PaymentRequest(
      order: null,
      lnInvoice: invoice,
      amount: amount,
    );
    await publishOrder(
      MostroMessage(
        action: Action.addInvoice,
        id: orderId,
        payload: payload,
      ),
    );
  }

  Future<void> cancelOrder(String orderId) async {
    await publishOrder(
      MostroMessage(
        action: Action.cancel,
        id: orderId,
      ),
    );
  }

  Future<void> sendFiatSent(String orderId) async {
    await publishOrder(
      MostroMessage(
        action: Action.fiatSent,
        id: orderId,
      ),
    );
  }

  Future<void> releaseOrder(String orderId) async {
    await publishOrder(
      MostroMessage(
        action: Action.release,
        id: orderId,
      ),
    );
  }

  Future<void> disputeOrder(String orderId) async {
    await publishOrder(
      MostroMessage(
        action: Action.dispute,
        id: orderId,
      ),
    );
  }

  Future<void> submitRating(String orderId, int rating) async {
    await publishOrder(
      MostroMessage(
        action: Action.rateUser,
        id: orderId,
        payload: RatingUser(userRating: rating),
      ),
    );
  }

  Future<void> publishOrder(MostroMessage order) async {
    final session = await _getSession(order);
    
    // Use lower difficulty for testing to prevent timeouts
    // In test environments, use difficulty 1 instead of default 16
    final targetDifficulty = kDebugMode && _isTestEnvironment() ? 1 : 16;
    
    final event = await order.wrap(
      tradeKey: session.tradeKey,
      recipientPubKey: _settings.mostroPublicKey,
      masterKey: session.fullPrivacy ? null : session.masterKey,
      keyIndex: session.fullPrivacy ? null : session.keyIndex,
      targetDifficulty: targetDifficulty,
    );
    _logger.i('Sending DM, Event ID: ${event.id} with payload: ${order.toJson()}');
    await ref.read(nostrServiceProvider).publishEvent(event);
  }

  Future<Session> _getSession(MostroMessage order) async {
    final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
    if (order.requestId != null) {
      final session = sessionNotifier.getSessionByRequestId(order.requestId!);
      if (session == null) {
        throw Exception('No session found for requestId: ${order.requestId}');
      }
      return session;
    } else if (order.id != null) {
      final session = sessionNotifier.getSessionByOrderId(order.id!);
      if (session == null) {
        throw Exception('No session found for orderId: ${order.id}');
      }
      return session;
    }
    throw Exception('Order has neither requestId nor orderId');
  }

  /// Helper method to detect if we're running in a test environment
  /// This helps reduce proof-of-work difficulty during testing to prevent timeouts
  /// 
  /// Returns `true` if:
  /// 1. Running in debug mode, or
  /// 2. The 'MOSTRO_TEST_ENV' environment variable is set to 'true', or
  /// 3. The 'FLUTTER_TEST' environment variable is set (standard Flutter test environment)
  bool _isTestEnvironment() {
    // Check for debug mode first (fast path)
    if (kDebugMode) {
      return true;
    }
    
    // Check for standard Flutter test environment variable
    if (const bool.fromEnvironment('FLUTTER_TEST', defaultValue: false)) {
      return true;
    }
    
    // Check for custom test environment variable
    const testEnv = String.fromEnvironment('MOSTRO_TEST_ENV', defaultValue: '');
    return testEnv.toLowerCase() == 'true';
  }

  void updateSettings(Settings settings) {
    _settings = settings.copyWith();
  }
}
