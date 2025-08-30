import 'package:flutter/material.dart';
import 'package:mostro_mobile/data/models/notification.dart';
import 'package:mostro_mobile/features/notifications/widgets/timestamp_text.dart';

class NotificationFooter extends StatelessWidget {
  final NotificationModel notification;

  const NotificationFooter({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TimestampText(notification: notification),
      ],
    );
  }
}