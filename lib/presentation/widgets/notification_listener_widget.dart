import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/providers/event_store_providers.dart';

class NotificationListenerWidget extends ConsumerWidget {
  final Widget child;

  const NotificationListenerWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notification = ref.watch(globalNotificationProvider);

    if (notification != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notification.message),
            action: SnackBarAction(
              label: 'View',
              onPressed: notification.onTap,
            ),
          ),
        );

        // Clear the notification after displaying it
        ref.read(globalNotificationProvider.notifier).clearNotification();
      });
    }

    // Ensure the rest of the widget tree is displayed
    return child;
  }
}
