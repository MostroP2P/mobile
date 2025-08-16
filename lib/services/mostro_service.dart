import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:dart_nostr/dart_nostr.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/data/models/restore_session_payload.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

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
      if (result is! List || result.isEmpty) return;

      final Map<String, dynamic> root =
          (result[0] as Map).cast<String, dynamic>();

      // Handle restore-session payload specially
      if (root.containsKey('restore')) {
        final payload = RestoreSessionPayload.fromJson(root);
        final messageStorage = ref.read(mostroStorageProvider);
        final msg = MostroMessage<RestoreSessionPayload>(
          action: Action.sendDm,
          id: null,
          payload: payload,
          timestamp: decryptedEvent.createdAt?.millisecondsSinceEpoch,
        );
        await messageStorage.addMessage(decryptedEvent.id!, msg);
        _logger.i('Stored restore-session payload, Event ID: ${decryptedEvent.id}');
        return;
      }

      final msg = MostroMessage.fromJson(root);
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

  /// Sends a restore-session request using a temporary restore session
  Future<void> sendRestoreRequest() async {
    // Create a temporary session entry to route the response decryption
    final session = await ref
        .read(sessionNotifierProvider.notifier)
        .newSession(orderId: '__restore__');

    final restoreEnvelope = {
      'restore': {
        'version': 1,
        'action': 'restore-session',
        'payload': null,
      }
    };

    final content = '[${jsonEncode(restoreEnvelope)}, null]';

    // Build wrapped event manually using the same helpers used in MostroMessage.wrap
    final tradeKey = session.tradeKey;
    final keySet = session.fullPrivacy ? tradeKey : session.masterKey;

    final encryptedContent = await NostrUtils.createRumor(
        tradeKey, keySet.private, _settings.mostroPublicKey, content);
    final wrapperKeyPair = NostrUtils.generateKeyPair();
    final sealedContent = await NostrUtils.createSeal(
        keySet, wrapperKeyPair.private, _settings.mostroPublicKey, encryptedContent);
    final wrapped = await NostrUtils.createWrap(
        wrapperKeyPair, sealedContent, _settings.mostroPublicKey);

    await ref.read(nostrServiceProvider).publishEvent(wrapped);
    _logger.i('Sent restore-session request, Event ID: ${wrapped.id}');
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
    
    final event = await order.wrap(
      tradeKey: session.tradeKey,
      recipientPubKey: _settings.mostroPublicKey,
      masterKey: session.fullPrivacy ? null : session.masterKey,
      keyIndex: session.fullPrivacy ? null : session.keyIndex,
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

  void updateSettings(Settings settings) {
    _settings = settings.copyWith();
  }
}
