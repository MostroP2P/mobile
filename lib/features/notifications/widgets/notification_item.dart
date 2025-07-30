import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/notification_type.dart';
import 'package:mostro_mobile/data/models/notification.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:mostro_mobile/features/notifications/widgets/notification_type_icon.dart';
import 'package:mostro_mobile/shared/utils/datetime_extensions_utils.dart';
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
    }
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
            notification.title,
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
      decoration: BoxDecoration(
        color: AppTheme.statusPendingBackground,
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
    return Text(
      notification.message,
      style: _getMessageStyle(context),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
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
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '#${orderId.substring(0, 8)}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 10,
          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
          fontFamily: 'monospace',
        ),
      ),
    );
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
        // TODO: Implement other actions in the menu popup
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
            color: AppTheme.statusActive
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
}