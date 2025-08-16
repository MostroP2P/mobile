import 'package:flutter/material.dart';
import 'package:mostro_mobile/data/models/notification.dart';
import 'package:mostro_mobile/features/notifications/widgets/notification_header.dart';
import 'package:mostro_mobile/features/notifications/widgets/notification_message.dart';
import 'package:mostro_mobile/features/notifications/widgets/notification_footer.dart';

class NotificationContent extends StatelessWidget {
  final NotificationModel notification;

  const NotificationContent({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NotificationHeader(notification: notification),
        const SizedBox(height: 4),
        NotificationMessage(notification: notification),
        const SizedBox(height: 8),
        NotificationFooter(notification: notification),
      ],
    );
  }
}