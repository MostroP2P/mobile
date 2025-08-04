import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/features/notifications/notifiers/notification_temporary_state.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:mostro_mobile/features/notifications/utils/notification_message_mapper.dart';


class NotificationListenerWidget extends ConsumerWidget {
  final Widget child;

  const NotificationListenerWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<NotificationTemporaryState>(temporaryNotificationProvider, (previous, next) {
      if (next.show) {
        String message;
        
        if (next.customMessage != null) {
          // Handle custom messages with localization
          switch (next.customMessage) {
            case 'orderTimeoutTaker':
              message = S.of(context)!.orderTimeoutTaker;
              break;
            case 'orderTimeoutMaker':
              message = S.of(context)!.orderTimeoutMaker;
              break;
            case 'orderCanceled':
              message = S.of(context)!.orderCanceled;
              break;
            default:
              message = next.customMessage!;
          }
        } else {
          // Get localized title directly from action
          message = NotificationMessageMapper.getLocalizedTitle(context, next.action!);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2), // Show for 2 seconds
          ),
        );
        // Clear notification after showing to prevent repetition
        ref.read(notificationsProvider.notifier).clearTemporary();
      }
    });
    return child;
  }
}
