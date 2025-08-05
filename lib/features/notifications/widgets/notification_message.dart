import 'package:flutter/material.dart';
import 'package:mostro_mobile/data/models/notification.dart';
import 'package:mostro_mobile/features/notifications/utils/notification_message_mapper.dart';
import 'package:mostro_mobile/features/notifications/widgets/notification_details.dart';

class NotificationMessage extends StatelessWidget {
  final NotificationModel notification;

  const NotificationMessage({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          NotificationMessageMapper.getLocalizedMessage(context, notification.action),
          style: _getMessageStyle(context),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (notification.data.isNotEmpty) ...[
          const SizedBox(height: 8),
          NotificationDetails(notification: notification),
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