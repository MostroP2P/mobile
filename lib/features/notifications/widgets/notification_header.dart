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
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.titleMedium;
    final baseColor = notification.isRead 
        ? theme.textTheme.bodyMedium?.color ?? theme.textTheme.titleMedium?.color
        : theme.textTheme.titleMedium?.color;
    
    return baseStyle?.copyWith(
      fontWeight: FontWeight.w600,
      color: notification.isRead 
          ? baseColor?.withValues(alpha: 0.7)
          : baseColor,
    );
  }
}