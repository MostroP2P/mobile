import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/shared/providers/legible_handle_provider.dart';
import 'package:mostro_mobile/shared/providers.dart';

class NotificationDataExtractor {
  /// Extract notification data from MostroMessage
  /// If ref is null, will use fallback methods for nickname resolution
  static Future<NotificationData?> extractFromMostroMessage(MostroMessage event, Ref? ref, {Session? session}) async {
    Map<String, dynamic> values = {};
    bool isTemporary = false;
    
    switch (event.action) {
      case Action.newOrder:
        // No notification for new orders
        return null;
        
      case Action.buyerTookOrder:
        final order = event.getPayload<Order>();
        if (order == null) return null;
        
        // Extract buyer nym using provider or fallback
        final buyerNym = order.buyerTradePubkey != null
            ? (ref != null 
                ? ref.read(nickNameProvider(order.buyerTradePubkey!))
                : await _getNicknameFromDatabase(order.buyerTradePubkey))
            : 'Unknown';
        values['buyer_npub'] = buyerNym;
        break;
        
      case Action.payInvoice:
        // No additional values needed for this action
        break;
        
      case Action.addInvoice:
        final order = event.getPayload<Order>();
        final isAfterPaymentFailure = order?.status == Status.settledHoldInvoice;
        
        if (isAfterPaymentFailure) {
          final now = DateTime.now();
          values = {
            'fiat_amount': order?.fiatAmount,
            'fiat_code': order?.fiatCode,
            'failed_at': now.millisecondsSinceEpoch,
          };
        }
        break;
        
      case Action.holdInvoicePaymentAccepted:
        final order = event.getPayload<Order>();
        if (order == null) return null;
        
        values = {
          'fiat_code': order.fiatCode,
          'fiat_amount': order.fiatAmount,
          'payment_method': order.paymentMethod,
        };
        
        if (order.sellerTradePubkey != null) {
          final sellerNym = ref != null
              ? ref.read(nickNameProvider(order.sellerTradePubkey!))
              : await _getNicknameFromDatabase(order.sellerTradePubkey);
          values['seller_npub'] = sellerNym;
        }
        break;
        
      case Action.holdInvoicePaymentSettled:
        final order = event.getPayload<Order>();
        if (order?.buyerTradePubkey != null) {
          final buyerNym = ref != null
              ? ref.read(nickNameProvider(order!.buyerTradePubkey!))
              : await _getNicknameFromDatabase(order!.buyerTradePubkey);
          values['buyer_npub'] = buyerNym;
        }
        break;
        
      case Action.paymentFailed:
        final paymentFailed = event.getPayload<PaymentFailed>();
        values = {
          'payment_attempts': paymentFailed?.paymentAttempts,
          'payment_retries_interval': paymentFailed?.paymentRetriesInterval,
        };
        break;
        
      case Action.waitingSellerToPay:
        // Get expiration seconds from mostro instance or use default
        final expirationSeconds = ref != null
            ? ref.read(orderRepositoryProvider).mostroInstance?.expirationSeconds ?? Config.expirationSeconds
            : Config.expirationSeconds;
        values['expiration_seconds'] = expirationSeconds;
        break;
        
      case Action.waitingBuyerInvoice:
        // Get expiration seconds from mostro instance or use default
        try {
          final expirationSeconds = ref != null
              ? ref.read(orderRepositoryProvider).mostroInstance?.expirationSeconds ?? Config.expirationSeconds
              : Config.expirationSeconds;
          values['expiration_seconds'] = expirationSeconds;
          Logger().d('waitingBuyerInvoice: extracted expiration_seconds=$expirationSeconds');
        } catch (e) {
          Logger().e('waitingBuyerInvoice: Error accessing providers: $e');
          values['expiration_seconds'] = Config.expirationSeconds;
        }
        break;
        
      case Action.fiatSentOk:
        // Only sellers should receive fiat confirmed notifications
        if (session?.role != Role.seller) return null;
        
        final peer = event.getPayload<Peer>();
        if (peer?.publicKey != null) {
          final buyerNym = ref != null
              ? ref.read(nickNameProvider(peer!.publicKey))
              : await _getNicknameFromDatabase(peer!.publicKey);
          values['buyer_npub'] = buyerNym;
        }
        break;
        
      case Action.released:
        final order = event.getPayload<Order>();
        if (order?.sellerTradePubkey != null) {
          final sellerNym = ref != null
              ? ref.read(nickNameProvider(order!.sellerTradePubkey!))
              : await _getNicknameFromDatabase(order!.sellerTradePubkey);
          values['seller_npub'] = sellerNym;
        }
        break;
        
      case Action.purchaseCompleted:
        // No additional values needed
        break;
        
      case Action.canceled:
        // Canceled orders don't generate persistent notifications
        return null;
        
      case Action.cooperativeCancelInitiatedByYou:
        // No additional values needed
        break;
        
      case Action.cooperativeCancelInitiatedByPeer:
        // No additional values needed
        break;
        
      case Action.disputeInitiatedByYou:
        final dispute = event.getPayload<Dispute>();
        if (dispute == null) return null;
        
        values['user_token'] = dispute.disputeId;
        break;
        
      case Action.disputeInitiatedByPeer:
        final dispute = event.getPayload<Dispute>();
        if (dispute == null) return null;
        
        values['user_token'] = dispute.disputeId;
        break;
        
      case Action.adminSettled:
        // No additional values needed
        break;
        
      case Action.cantDo:
        final cantDo = event.getPayload<CantDo>();
        values['action'] = cantDo?.cantDoReason.toString();
        isTemporary = true; // cantDo notifications are temporary
        break;
        
      case Action.rate:
        // No additional values needed
        break;
        
      case Action.rateReceived:
        // This action doesn't generate notifications
        return null;
        
      case Action.timeoutReversal:
        // This action doesn't generate notifications
        return null;
        
      default:
        // Unknown actions generate temporary notifications
        isTemporary = true;
        break;
    }
    
    return NotificationData(
      action: event.action,
      values: values,
      orderId: event.id,
      eventId: event.id,
      isTemporary: isTemporary,
    );
  }

  /// Get nickname using the same deterministic method as foreground
  static Future<String> _getNicknameFromDatabase(String? publicKey) async {
    if (publicKey == null) return 'Unknown';
    if (publicKey.isEmpty) return 'Unknown';
    try {
      final result = deterministicHandleFromHexKey(publicKey);
      return result.isNotEmpty ? result : 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }
}

class NotificationData {
  final Action action;
  final Map<String, dynamic> values;
  final String? orderId;
  final String? eventId;
  final bool isTemporary;
  
  const NotificationData({
    required this.action,
    required this.values,
    this.orderId,
    this.eventId,
    this.isTemporary = false,
  });
}