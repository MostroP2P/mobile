import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as mostro_action;
import 'package:mostro_mobile/data/models/notification.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:mostro_mobile/features/notifications/widgets/notification_type_icon.dart';
import 'package:mostro_mobile/features/notifications/widgets/notification_content.dart';
import 'package:mostro_mobile/features/notifications/widgets/notification_menu.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class NotificationItem extends ConsumerWidget {
  final NotificationModel notification;

  const NotificationItem({
    super.key,
    required this.notification,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: _getCardColor(context),
      child: InkWell(
        onTap: () => _handleNotificationTap(context, ref),
        borderRadius: _getCardBorderRadius(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NotificationTypeIcon(
                type: notification.type,
                action: notification.action,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NotificationContent(notification: notification),
              ),
              const SizedBox(width: 8),
              NotificationMenu(
                notification: notification,
                onMenuAction: (value) => _handleMenuAction(context, ref, value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color? _getCardColor(BuildContext context) {
    return notification.isRead 
        ? Theme.of(context).cardTheme.color 
        : Theme.of(context).cardTheme.color?.withValues(alpha: 0.9);
  }

  BorderRadius _getCardBorderRadius(BuildContext context) {
    return Theme.of(context).cardTheme.shape is RoundedRectangleBorder
        ? (Theme.of(context).cardTheme.shape as RoundedRectangleBorder).borderRadius as BorderRadius
        : BorderRadius.circular(12);
  }

  void _handleNotificationTap(BuildContext context, WidgetRef ref) {
    // Mark as read when tapped
    if (!notification.isRead) {
      ref.read(notificationsDatabaseProvider).markAsRead(notification.id);
    }

    final navProvider = ref.read(navigationProvider.notifier);

    if (notification.orderId != null) {
      switch (notification.action) {
        case mostro_action.Action.addInvoice:
          navProvider.go('/add_invoice/${notification.orderId}');
          break;
        case mostro_action.Action.canceled:
        case mostro_action.Action.adminCanceled:
          navProvider.go('/order_book');
          break;
        case mostro_action.Action.rate:
          navProvider.go('/rate_user/${notification.orderId}');
          break;
        case mostro_action.Action.payInvoice:
        case mostro_action.Action.fiatSentOk:
        case mostro_action.Action.released:
        case mostro_action.Action.holdInvoicePaymentAccepted:
        case mostro_action.Action.holdInvoicePaymentSettled:
        case mostro_action.Action.waitingSellerToPay:
        case mostro_action.Action.waitingBuyerInvoice:
        case mostro_action.Action.buyerTookOrder:
        case mostro_action.Action.disputeInitiatedByYou:
        case mostro_action.Action.disputeInitiatedByPeer:
        case mostro_action.Action.adminSettled:
        case mostro_action.Action.paymentFailed:
        case mostro_action.Action.purchaseCompleted:
        case mostro_action.Action.cooperativeCancelInitiatedByYou:
        case mostro_action.Action.cooperativeCancelInitiatedByPeer:
        case mostro_action.Action.sendDm:
          navProvider.go('/trade_detail/${notification.orderId}');
          break;
        case mostro_action.Action.cantDo:
        case mostro_action.Action.timeoutReversal:
        case mostro_action.Action.rateReceived:
          break;
        default:
          break;
      }
    }
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'mark_read':
        ref.read(notificationsDatabaseProvider).markAsRead(notification.id);
        break;
      case 'delete':
        _showDeleteConfirmationDialog(context, ref);
        break;
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundDark,
        title: Text(
          S.of(context)!.notificationDelete,
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          S.of(context)!.confirmDeleteNotification,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              S.of(context)!.cancel,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(notificationsDatabaseProvider).deleteNotification(notification.id);
              Navigator.of(context).pop();
            },
            child: Text(
              S.of(context)!.notificationDelete,
              style: const TextStyle(color: AppTheme.statusError),
            ),
          ),
        ],
      ),
    );
  }
}