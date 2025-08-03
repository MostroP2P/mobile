import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/notification_type.dart';
import 'package:mostro_mobile/data/models/notification.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as mostro_action;
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:mostro_mobile/features/notifications/widgets/notification_type_icon.dart';
import 'package:mostro_mobile/shared/utils/datetime_extensions_utils.dart';
import 'package:mostro_mobile/generated/l10n.dart';

// Helper function to resolve localization keys
String _resolveNotificationText(BuildContext context, String key) {
  final s = S.of(context)!;
  
  // Map notification keys to actual localized strings
  switch (key) {
    case 'notification_new_order_title':
      return s.notification_new_order_title;
    case 'notification_new_order_message':
      return s.notification_new_order_message;
    case 'notification_order_taken_title':
      return s.notification_order_taken_title;
    case 'notification_sell_order_taken_message':
      return s.notification_sell_order_taken_message;
    case 'notification_buy_order_taken_message':
      return s.notification_buy_order_taken_message;
    case 'notification_payment_required_title':
      return s.notification_payment_required_title;
    case 'notification_payment_required_message':
      return s.notification_payment_required_message;
    case 'notification_fiat_sent_title':
      return s.notification_fiat_sent_title;
    case 'notification_fiat_sent_message':
      return s.notification_fiat_sent_message;
    case 'notification_bitcoin_released_title':
      return s.notification_bitcoin_released_title;
    case 'notification_bitcoin_released_message':
      return s.notification_bitcoin_released_message;
    case 'notification_dispute_started_title':
      return s.notification_dispute_started_title;
    case 'notification_dispute_started_message':
      return s.notification_dispute_started_message;
    case 'notification_order_canceled_title':
      return s.notification_order_canceled_title;
    case 'notification_order_canceled_message':
      return s.notification_order_canceled_message;
    case 'notification_cooperative_cancel_initiated_by_you_title':
      return s.notification_cooperative_cancel_initiated_by_you_title;
    case 'notification_cooperative_cancel_initiated_by_you_message':
      return s.notification_cooperative_cancel_initiated_by_you_message;
    case 'notification_cooperative_cancel_initiated_by_peer_title':
      return s.notification_cooperative_cancel_initiated_by_peer_title;
    case 'notification_cooperative_cancel_initiated_by_peer_message':
      return s.notification_cooperative_cancel_initiated_by_peer_message;
    case 'notification_cooperative_cancel_accepted_title':
      return s.notification_cooperative_cancel_accepted_title;
    case 'notification_cooperative_cancel_accepted_message':
      return s.notification_cooperative_cancel_accepted_message;
    case 'notification_fiat_sent_ok_title':
      return s.notification_fiat_sent_ok_title;
    case 'notification_fiat_sent_ok_message':
      return s.notification_fiat_sent_ok_message;
    case 'notification_release_title':
      return s.notification_release_title;
    case 'notification_release_message':
      return s.notification_release_message;
    case 'notification_buyer_invoice_accepted_title':
      return s.notification_buyer_invoice_accepted_title;
    case 'notification_buyer_invoice_accepted_message':
      return s.notification_buyer_invoice_accepted_message;
    case 'notification_purchase_completed_title':
      return s.notification_purchase_completed_title;
    case 'notification_purchase_completed_message':
      return s.notification_purchase_completed_message;
    case 'notification_hold_invoice_payment_accepted_title':
      return s.notification_hold_invoice_payment_accepted_title;
    case 'notification_hold_invoice_payment_accepted_message':
      return s.notification_hold_invoice_payment_accepted_message;
    case 'notification_hold_invoice_payment_settled_title':
      return s.notification_hold_invoice_payment_settled_title;
    case 'notification_hold_invoice_payment_settled_message':
      return s.notification_hold_invoice_payment_settled_message;
    case 'notification_hold_invoice_payment_canceled_title':
      return s.notification_hold_invoice_payment_canceled_title;
    case 'notification_hold_invoice_payment_canceled_message':
      return s.notification_hold_invoice_payment_canceled_message;
    case 'notification_waiting_seller_to_pay_title':
      return s.notification_waiting_seller_to_pay_title;
    case 'notification_waiting_seller_to_pay_message':
      return s.notification_waiting_seller_to_pay_message;
    case 'notification_waiting_buyer_invoice_title':
      return s.notification_waiting_buyer_invoice_title;
    case 'notification_waiting_buyer_invoice_message':
      return s.notification_waiting_buyer_invoice_message;
    case 'notification_add_invoice_title':
      return s.notification_add_invoice_title;
    case 'notification_add_invoice_message':
      return s.notification_add_invoice_message;
    case 'notification_buyer_took_order_title':
      return s.notification_buyer_took_order_title;
    case 'notification_buyer_took_order_message':
      return s.notification_buyer_took_order_message;
    case 'notification_rate_title':
      return s.notification_rate_title;
    case 'notification_rate_message':
      return s.notification_rate_message;
    case 'notification_rate_received_title':
      return s.notification_rate_received_title;
    case 'notification_rate_received_message':
      return s.notification_rate_received_message;
    case 'notification_dispute_initiated_by_you_title':
      return s.notification_dispute_initiated_by_you_title;
    case 'notification_dispute_initiated_by_you_message':
      return s.notification_dispute_initiated_by_you_message;
    case 'notification_dispute_initiated_by_peer_title':
      return s.notification_dispute_initiated_by_peer_title;
    case 'notification_dispute_initiated_by_peer_message':
      return s.notification_dispute_initiated_by_peer_message;
    case 'notification_payment_failed_title':
      return s.notification_payment_failed_title;
    case 'notification_payment_failed_message':
      return s.notification_payment_failed_message;
    case 'notification_invoice_updated_title':
      return s.notification_invoice_updated_title;
    case 'notification_invoice_updated_message':
      return s.notification_invoice_updated_message;
    case 'notification_cant_do_title':
      return s.notification_cant_do_title;
    case 'notification_cant_do_message':
      return s.notification_cant_do_message;
    case 'notification_new_message_title':
      return s.notification_new_message_title;
    case 'notification_new_message_message':
      return s.notification_new_message_message;
    case 'notification_order_update_title':
      return s.notification_order_update_title;
    case 'notification_order_update_message':
      return s.notification_order_update_message;
    default:
      // Fallback: if it's not a key, return as is (backward compatibility)
      return key;
  }
}

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
                child: _NotificationContent(notification: notification),
              ),
              const SizedBox(width: 8),
              _NotificationMenu(
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
      ref.read(notificationsProvider.notifier).markAsRead(notification.id);
    }

    //TODO: Implement navigation based on notification type
    if (notification.orderId != null) {
      switch (notification.type) {
        case NotificationType.orderUpdate:
        case NotificationType.tradeUpdate:
        case NotificationType.payment:
        case NotificationType.dispute:
        case NotificationType.cancellation:
        case NotificationType.message:
        case NotificationType.system:
          break;
      }
    }
   
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'mark_read':
        ref.read(notificationsProvider.notifier).markAsRead(notification.id);
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
          S.of(context)!.delete,
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
              ref.read(notificationsProvider.notifier).deleteNotification(notification.id);
              Navigator.of(context).pop();
            },
            child: Text(
              S.of(context)!.delete,
              style: const TextStyle(color: AppTheme.statusError),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationContent extends StatelessWidget {
  final NotificationModel notification;

  const _NotificationContent({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NotificationHeader(notification: notification),
        const SizedBox(height: 4),
        _NotificationMessage(notification: notification),
        const SizedBox(height: 8),
        _NotificationFooter(notification: notification),
      ],
    );
  }
}

class _NotificationHeader extends StatelessWidget {
  final NotificationModel notification;

  const _NotificationHeader({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _resolveNotificationText(context, notification.title),
            style: _getTitleStyle(context),
          ),
        ),
        if (!notification.isRead) const _UnreadIndicator(),
      ],
    );
  }

  TextStyle? _getTitleStyle(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: notification.isRead
          ? Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)
          : Theme.of(context).textTheme.titleMedium?.color,
    );
  }
}

class _UnreadIndicator extends StatelessWidget {
  const _UnreadIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppTheme.mostroGreen,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _NotificationMessage extends StatelessWidget {
  final NotificationModel notification;

  const _NotificationMessage({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _resolveNotificationText(context, notification.message),
          style: _getMessageStyle(context),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (notification.data.isNotEmpty) ...[
          const SizedBox(height: 8),
          _NotificationDetails(notification: notification),
        ],
      ],
    );
  }

  TextStyle? _getMessageStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: notification.isRead
          ? Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6)
          : Theme.of(context).textTheme.bodyMedium?.color,
    );
  }
}

class _NotificationDetails extends StatelessWidget {
  final NotificationModel notification;

  const _NotificationDetails({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppTheme.smallPadding,
      decoration: BoxDecoration(
        color: AppTheme.backgroundInput.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.textInactive.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildDetailsWidgets(context),
      ),
    );
  }

  List<Widget> _buildDetailsWidgets(BuildContext context) {
    final widgets = <Widget>[];
    final data = notification.data;

    switch (notification.action) {
      case mostro_action.Action.fiatSentOk:
        if (data.containsKey('buyer_npub')) {
          widgets.add(_DetailRow(
            label: S.of(context)!.buyer,
            value: _formatHashOrId(data['buyer_npub']),
            icon: HeroIcons.user,
          ));
        }
        break;

      case mostro_action.Action.holdInvoicePaymentAccepted:
        if (data.containsKey('seller_npub')) {
          widgets.add(_DetailRow(
            label: S.of(context)!.seller,
            value: _formatHashOrId(data['seller_npub']),
            icon: HeroIcons.user,
          ));
        }
        if (data.containsKey('fiat_amount') && data.containsKey('fiat_code')) {
          widgets.add(_DetailRow(
            label: S.of(context)!.amount,
            value: '${data['fiat_amount']} ${data['fiat_code']}',
            icon: HeroIcons.banknotes,
          ));
        }
        if (data.containsKey('payment_method')) {
          widgets.add(_DetailRow(
            label: S.of(context)!.paymentMethod,
            value: data['payment_method'].toString(),
            icon: HeroIcons.creditCard,
          ));
        }
        break;

      case mostro_action.Action.waitingSellerToPay:
      case mostro_action.Action.waitingBuyerInvoice:
        if (data.containsKey('expiration_seconds')) {
          final expirationSeconds = data['expiration_seconds'];
          final expirationMinutes = (expirationSeconds is int ? expirationSeconds : int.tryParse(expirationSeconds.toString()) ?? 0) ~/ 60;
          widgets.add(_DetailRow(
            label: S.of(context)!.timeout,
            value: '$expirationMinutes ${S.of(context)!.minutes}',
            icon: HeroIcons.clock,
          ));
        }
        break;

      case mostro_action.Action.disputeInitiatedByYou:
      case mostro_action.Action.disputeInitiatedByPeer:
        if (data.containsKey('user_token')) {
          widgets.add(_DetailRow(
            label: S.of(context)!.disputeId,
            value: _formatHashOrId(data['user_token'].toString()),
            icon: HeroIcons.exclamationTriangle,
          ));
        }
        break;

      case mostro_action.Action.paymentFailed:
        if (data.containsKey('payment_attempts')) {
          widgets.add(_DetailRow(
            label: S.of(context)!.attempts,
            value: data['payment_attempts'].toString(),
            icon: HeroIcons.arrowPath,
          ));
        }
        if (data.containsKey('payment_retries_interval')) {
          widgets.add(_DetailRow(
            label: S.of(context)!.retryInterval,
            value: '${data['payment_retries_interval']}s',
            icon: HeroIcons.clock,
          ));
        }
        break;

      case mostro_action.Action.cantDo:
        if (data.containsKey('action')) {
          widgets.add(_DetailRow(
            label: S.of(context)!.reason,
            value: data['action'].toString(),
            icon: HeroIcons.xMark,
          ));
        }
        break;

      case mostro_action.Action.released:
        if (data.containsKey('seller_npub') && data['seller_npub'].toString().isNotEmpty) {
          widgets.add(_DetailRow(
            label: S.of(context)!.seller,
            value: _formatHashOrId(data['seller_npub']),
            icon: HeroIcons.user,
          ));
        }
        break;

      case mostro_action.Action.holdInvoicePaymentSettled:
        if (data.containsKey('buyer_npub') && data['buyer_npub'].toString().isNotEmpty) {
          widgets.add(_DetailRow(
            label: S.of(context)!.buyer,
            value: _formatHashOrId(data['buyer_npub']),
            icon: HeroIcons.user,
          ));
        }
        break;

      case mostro_action.Action.canceled:
        if (data.containsKey('id')) {
          widgets.add(_DetailRow(
            label: S.of(context)!.orderId,
            value: _formatHashOrId(data['id'].toString()),
            icon: HeroIcons.hashtag,
          ));
        }
        break;

      case mostro_action.Action.cooperativeCancelInitiatedByYou:
      case mostro_action.Action.cooperativeCancelInitiatedByPeer:
      case mostro_action.Action.cooperativeCancelAccepted:
        if (data.containsKey('id')) {
          widgets.add(_DetailRow(
            label: S.of(context)!.orderId,
            value: _formatHashOrId(data['id'].toString()),
            icon: HeroIcons.hashtag,
          ));
        }
        break;

      default:
        // TODO: Each new action should be handled specifically above with proper localization and formatting
        // This default case is a fallback for any unhandled actions
        data.forEach((key, value) {
          if (value != null && value.toString().isNotEmpty) {
            widgets.add(_DetailRow(
              label: _formatKey(key),
              value: _formatHashOrId(value.toString()),
              icon: HeroIcons.informationCircle,
            ));
          }
        });
        break;
    }

    return widgets;
  }

  String _formatHashOrId(String value) {
    if (value.isEmpty) return 'N/A';
    
    if (value.length <= 8) {
      return value; // Show full value if it's short enough
    }
    
    String start = value.substring(0, 8);
    String end = value.substring(value.length - 5);
    
    return '$start...$end';
  }

  String _formatKey(String key) {
    return key.replaceAll('_', ' ').split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final HeroIcons icon;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          HeroIcon(
            icon,
            style: HeroIconStyle.outline,
            size: 14,
            color: AppTheme.textSecondary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: value.contains('npub') || value.contains('#') ? 'monospace' : null,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationFooter extends StatelessWidget {
  final NotificationModel notification;

  const _NotificationFooter({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TimestampText(notification: notification),
        const Spacer(),
        if (notification.orderId != null)
          _OrderIdChip(orderId: notification.orderId!),
      ],
    );
  }
}

class _TimestampText extends StatelessWidget {
  final NotificationModel notification;

  const _TimestampText({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Text(
      notification.timestamp.timeAgoWithLocale(context),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
      ),
    );
  }
}

class _OrderIdChip extends StatelessWidget {
  final String orderId;

  const _OrderIdChip({required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppTheme.smallPadding,
      decoration: BoxDecoration(
        color: AppTheme.backgroundInput.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '#${_formatOrderId(orderId)}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 10,
          color: AppTheme.textInactive,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  String _formatOrderId(String orderId) {
    if (orderId.length <= 16) {
      return orderId;
    }
    return '${orderId.substring(0, 8)}...${orderId.substring(orderId.length - 5)}';
  }
}

class _NotificationMenu extends StatelessWidget {
  final NotificationModel notification;
  final Function(String) onMenuAction;

  const _NotificationMenu({
    required this.notification,
    required this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    
    return PopupMenuButton<String>(
      icon: HeroIcon(
        HeroIcons.ellipsisVertical,
        style: HeroIconStyle.outline,
        size: 16,
        color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.6),
      ),
      color: Theme.of(context).cardTheme.color,
      onSelected: onMenuAction,
      itemBuilder: (context) => [
        if (!notification.isRead) _buildMarkAsReadMenuItem(context),
        _buildDeleteMenuItem(context),
      ],
      
    );
  }

  PopupMenuItem<String> _buildMarkAsReadMenuItem(BuildContext context) {
    return PopupMenuItem(
      value: 'mark_read',
      child: Row(
        children: [
          HeroIcon(
            HeroIcons.check,
            style: HeroIconStyle.outline,
            size: 16,
            color: AppTheme.statusSuccess
          ),
          const SizedBox(width: 8),
          Text(
            S.of(context)!.markAsRead,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildDeleteMenuItem(BuildContext context) {
    return PopupMenuItem(
      value: 'delete',
      child: Row(
        children: [
          const HeroIcon(
            HeroIcons.trash,
            style: HeroIconStyle.outline,
            size: 16,
            color: AppTheme.statusError,
          ),
          const SizedBox(width: 8),
          Text(
            S.of(context)!.delete,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.statusError,
            ),
          ),
        ],
      ),
    );
  }
}