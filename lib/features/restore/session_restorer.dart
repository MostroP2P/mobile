import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SessionRestorer {
  final Ref ref;
  final Logger _logger = Logger();

  SessionRestorer(this.ref);

  Future<void> restoreSessions({
    required List<dynamic>? restoreOrders,
    required List<dynamic>? restoreDisputes,
    required List<dynamic>? orderDetails,
  }) async {
    final keyManager = ref.read(keyManagerProvider);
    final settings = ref.read(settingsProvider);
    final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
    final storage = ref.read(mostroStorageProvider);
    final masterKey = keyManager.masterKeyPair!;

    int restoredCount = 0;

    if (restoreOrders != null) {
      for (final order in restoreOrders) {
        final orderId = order['order_id'] as String?;
        final tradeIndex = order['trade_index'] as int?;

        if (orderId != null && tradeIndex != null) {
          final tradeKey = await keyManager.deriveTradeKeyFromIndex(tradeIndex);
          final role = await _determineRole(orderId, tradeIndex, orderDetails);

          final session = Session(
            masterKey: masterKey,
            tradeKey: tradeKey,
            keyIndex: tradeIndex,
            fullPrivacy: settings.fullPrivacyMode,
            startTime: DateTime.now(),
            orderId: orderId,
            role: role,
          );

          await sessionNotifier.saveSession(session);

          // Save order details as MostroMessage
          await _saveOrderDetailsAsMessage(orderId, orderDetails, storage);

          restoredCount++;
        }
      }
    }

    if (restoreDisputes != null) {
      for (final dispute in restoreDisputes) {
        final orderId = dispute['order_id'] as String?;
        final tradeIndex = dispute['trade_index'] as int?;

        if (orderId != null && tradeIndex != null) {
          final tradeKey = await keyManager.deriveTradeKeyFromIndex(tradeIndex);
          final role = await _determineRole(orderId, tradeIndex, orderDetails);

          final session = Session(
            masterKey: masterKey,
            tradeKey: tradeKey,
            keyIndex: tradeIndex,
            fullPrivacy: settings.fullPrivacyMode,
            startTime: DateTime.now(),
            orderId: orderId,
            role: role,
          );

          await sessionNotifier.saveSession(session);

          // Save order details as MostroMessage
          await _saveOrderDetailsAsMessage(orderId, orderDetails, storage);

          restoredCount++;
        }
      }
    }

    _logger.i('Restored $restoredCount sessions');
  }

  Future<Role?> _determineRole(
    String orderId,
    int tradeIndex,
    List<dynamic>? orderDetails,
  ) async {
    if (orderDetails == null || orderDetails.isEmpty) return null;

    Map<String, dynamic>? orderDetail;
    try {
      orderDetail = orderDetails.firstWhere(
        (order) => order['id'] == orderId,
      ) as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }

    if (orderDetail == null) return null;

    final keyManager = ref.read(keyManagerProvider);
    final tradeKey = await keyManager.deriveTradeKeyFromIndex(tradeIndex);

    final buyerPubkey = orderDetail['buyer_trade_pubkey'] as String?;
    final sellerPubkey = orderDetail['seller_trade_pubkey'] as String?;

    if (buyerPubkey != null && tradeKey.public == buyerPubkey) {
      return Role.buyer;
    } else if (sellerPubkey != null && tradeKey.public == sellerPubkey) {
      return Role.seller;
    }

    return null;
  }

  Future<void> cleanupTempSession(String tempTradePublicKey) async {
    final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
    final tempSession = sessionNotifier.getSessionByTradeKey(tempTradePublicKey);

    if (tempSession != null && tempSession.orderId != null) {
      await sessionNotifier.deleteSession(tempSession.orderId!);
      _logger.d('Cleanup: removed temporary session');
    }
  }

  Future<void> updateKeyIndex(int lastTradeIndex) async {
    final keyManager = ref.read(keyManagerProvider);
    await keyManager.setCurrentKeyIndex(lastTradeIndex + 1);
    _logger.i('Key index updated to ${lastTradeIndex + 1}');
  }

  Future<void> _saveOrderDetailsAsMessage(
    String orderId,
    List<dynamic>? orderDetails,
    dynamic storage,
  ) async {
    if (orderDetails == null || orderDetails.isEmpty) {
      _logger.w('No order details to save for order $orderId');
      return;
    }

    try {
      Map<String, dynamic>? orderDetail;

      for (final detail in orderDetails) {
        if (detail is Map<String, dynamic> && detail['id'] == orderId) {
          orderDetail = detail;
          break;
        }
      }

      if (orderDetail == null) {
        _logger.w('Order detail not found for order $orderId');
        return;
      }

      final order = Order.fromJson(orderDetail);
      final action = _mapStatusToAction(order.status);

      final message = MostroMessage<Order>(
        id: orderId,
        action: action,
        payload: order,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      final messageKey = '$orderId-restore-${DateTime.now().millisecondsSinceEpoch}';
      await storage.addMessage(messageKey, message);

      _logger.i('Saved order details as message for order $orderId with action $action');
    } catch (e, stack) {
      _logger.e('Failed to save order details for $orderId', error: e, stackTrace: stack);
    }
  }

  Action _mapStatusToAction(Status status) {
    switch (status) {
      case Status.pending:
        return Action.newOrder;
      case Status.waitingPayment:
        return Action.waitingSellerToPay;
      case Status.waitingBuyerInvoice:
        return Action.waitingBuyerInvoice;
      case Status.active:
        return Action.holdInvoicePaymentAccepted;
      case Status.fiatSent:
        return Action.fiatSentOk;
      case Status.success:
        return Action.purchaseCompleted;
      case Status.canceled:
        return Action.canceled;
      case Status.dispute:
        return Action.disputeInitiatedByYou;
      case Status.cooperativelyCanceled:
        return Action.cooperativeCancelInitiatedByYou;
      case Status.settledByAdmin:
        return Action.adminSettled;
      case Status.canceledByAdmin:
        return Action.adminCanceled;
      case Status.paymentFailed:
        return Action.paymentFailed;
      default:
        return Action.newOrder;
    }
  }
}
