import 'package:flutter/material.dart';
import 'package:mostro_mobile/data/models/notification.dart';
import 'package:mostro_mobile/features/notifications/widgets/notification_text_resolver.dart';
import 'package:mostro_mobile/features/notifications/widgets/unread_indicator.dart';

class NotificationHeader extends StatelessWidget {
  final NotificationModel notification;

  const NotificationHeader({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            resolveNotificationText(context, notification.title),
            style: _getTitleStyle(context),
          ),
        ),
        if (!notification.isRead) const UnreadIndicator(),
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