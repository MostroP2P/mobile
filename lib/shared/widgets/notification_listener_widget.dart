import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/shared/notifiers/notification_notifier.dart';
import 'package:mostro_mobile/shared/providers/notification_notifier_provider.dart';

class NotificationListenerWidget extends ConsumerWidget {
  final Widget child;

  const NotificationListenerWidget(
      {super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<NotificationState>(notificationProvider, (previous, next) {
      if (next.informational) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message!)),
        );
        // Clear notification after showing to prevent repetition
        ref.read(notificationProvider.notifier).clearNotification();
      } else if (next.actionRequired){
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Action Required'),
            content: Text('Please add your lightning invoice to proceed.'),
            actions: [
              TextButton(
                onPressed: () => context.go('/'),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  // Perform the required action
                  Navigator.of(context).pop();
                },
                child: Text('Add Invoice'),
              ),
            ],
          ),
        );
      }
    });
    return child;
  }
}
