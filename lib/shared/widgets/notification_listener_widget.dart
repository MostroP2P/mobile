import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/shared/notifiers/notification_notifier.dart';
import 'package:mostro_mobile/shared/providers/notification_notifier_provider.dart';

class NotificationListenerWidget extends ConsumerWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigator;

  const NotificationListenerWidget(
      {super.key, required this.child, required this.navigator});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      
    ref.listen<NotificationState>(notificationProvider, (previous, next) {
      if (next.showSnackbar && next.message != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message!.action.value)),
        );
        // Clear notification after showing to prevent repetition
        ref.read(notificationProvider.notifier).clearNotification();
      }

    });
    return child;
  }
}
