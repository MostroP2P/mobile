import 'dart:async';
import 'dart:convert';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/subscription_manager_provider.dart';

class MostroService {
  final Ref ref;
  static final Logger _logger = Logger();
  
  final Set<String> _subscribedPubKeys = {};
  StreamSubscription<NostrEvent>? _subscription;
  Settings _settings;
  
  MostroService(this.ref) : _settings = ref.read(settingsProvider);

  void init() {
    ref.listen<List<Session>>(sessionNotifierProvider, (previous, next) {
      if (next.isNotEmpty) {
        for (final session in next) {
          subscribe(session.tradeKey.public);
        }
      } else {
        _clearSubscriptions();
      }
    });
  }

  void dispose() {
    _clearSubscriptions();
    _subscription?.cancel();
  }

  /// Subscribes to events for a specific public key.
  /// 
  /// This method adds the public key to the internal set of subscribed keys
  /// and updates the subscription if the key was not already being tracked.
  /// 
  /// Throws an [ArgumentError] if [pubKey] is empty or invalid.
  /// 
  /// [pubKey] The public key to subscribe to (must be a valid Nostr public key)
  void subscribe(String pubKey) {
    if (pubKey.isEmpty) {
      _logger.w('Attempted to subscribe to empty pubKey');
      throw ArgumentError('pubKey cannot be empty');
    }
    
    try {
      if (_subscribedPubKeys.add(pubKey)) {
        _logger.i('Added subscription for pubKey: $pubKey');
        _updateSubscription();
      } else {
        _logger.d('Already subscribed to pubKey: $pubKey');
      }
    } catch (e, stackTrace) {
      _logger.e('Invalid public key: $pubKey', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  void unsubscribe(String pubKey) {
    _subscribedPubKeys.remove(pubKey);
    _updateSubscription();
  }

  void _clearSubscriptions() {
    _subscription?.cancel();
    _subscription = null;
    _subscribedPubKeys.clear();
    
    final subscriptionManager = ref.read(subscriptionManagerProvider.notifier);
    subscriptionManager.subscribe(NostrFilter());
  }

  /// Updates the current subscription with the latest set of public keys.
  /// 
  /// This method creates a new subscription with the current set of public keys
  /// and cancels any existing subscription. If there are no public keys to
  /// subscribe to, it clears all subscriptions.
  void _updateSubscription() {
    _subscription?.cancel();
    
    if (_subscribedPubKeys.isEmpty) {
      _clearSubscriptions();
      return;
    }
    
    try {
      final filter = NostrFilter(
        kinds: [1059],
        p: _subscribedPubKeys.toList(),
      );
            
      final subscriptionManager = ref.read(subscriptionManagerProvider.notifier);
      _subscription = subscriptionManager.subscribe(filter).listen(
        _onData,
        onError: (error, stackTrace) {
          _logger.e('Error in subscription', error: error, stackTrace: stackTrace);
        },
        cancelOnError: false,
      );
    } catch (e, stackTrace) {
      _logger.e('Error updating subscription', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> _onData(NostrEvent event) async {
    if (event.recipient == null || !_subscribedPubKeys.contains(event.recipient)) return;

    final eventStore = ref.read(eventStorageProvider);

    if (await eventStore.hasItem(event.id!)) return;
    await eventStore.putItem(
      event.id!,
      event,
    );

    final sessions = ref.read(sessionNotifierProvider);
    Session? matchingSession;
    
    try {
      matchingSession = sessions.firstWhere(
        (s) => s.tradeKey.public == event.recipient,
      );
    } catch (e) {
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
        'Received message of type ${msg.action} with order id ${msg.id}',
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
    final event = await order.wrap(
      tradeKey: session.tradeKey,
      recipientPubKey: _settings.mostroPublicKey,
      masterKey: session.fullPrivacy ? null : session.masterKey,
      keyIndex: session.fullPrivacy ? null : session.keyIndex,
    );

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
