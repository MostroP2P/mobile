import 'package:flutter/material.dart';
import 'package:mostro_mobile/data/models/notification.dart';
import 'package:mostro_mobile/shared/utils/datetime_extensions_utils.dart';

class TimestampText extends StatelessWidget {
  final NotificationModel notification;

  const TimestampText({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    return Text(
      notification.timestamp.preciseTimeAgo(context),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
      ),
    );
  }
}