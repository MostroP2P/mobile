import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/notification_type.dart';
import 'package:mostro_mobile/data/models/notification.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:mostro_mobile/features/notifications/widgets/notification_type_icon.dart';
import 'package:mostro_mobile/features/notifications/widgets/notification_content.dart';
import 'package:mostro_mobile/features/notifications/widgets/notification_menu.dart';
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