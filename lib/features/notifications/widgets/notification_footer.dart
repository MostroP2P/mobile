import 'package:flutter/material.dart';
import 'package:mostro_mobile/data/models/notification.dart';
import 'package:mostro_mobile/features/notifications/widgets/timestamp_text.dart';
import 'package:mostro_mobile/features/notifications/widgets/order_id_chip.dart';

class NotificationFooter extends StatelessWidget {
  final NotificationModel notification;

  const NotificationFooter({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TimestampText(notification: notification),
        const Spacer(),
        if (notification.orderId != null)
          OrderIdChip(orderId: notification.orderId!),
      ],
    );
  }
}