import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/notifiers/notification_notifier.dart';
import 'package:mostro_mobile/shared/providers/notification_notifier_provider.dart';

class NotificationListenerWidget extends ConsumerWidget {
  final Widget child;

  const NotificationListenerWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<NotificationState>(notificationProvider, (previous, next) {
      if (next.informational) {
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
          // Handle specific actions with proper localization
          if (next.action == actions.Action.timeoutReversal) {
            // For timeoutReversal without custom message, use generic timeout message
            final l10n = S.of(context);
            message = l10n?.orderTimeout ?? 'Order timeout occurred';
          } else {
            final l10n = S.of(context);
            message = next.action?.toString() ?? l10n?.error ?? 'An error occurred';
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2), // Show for 2 seconds
          ),
        );
        // Clear notification after showing to prevent repetition
        ref.read(notificationProvider.notifier).clearNotification();
      } else if (next.actionRequired) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(S.of(context)!.error),
            content: Text(next.action?.toString() ?? S.of(context)!.error),
            actions: [
              TextButton(
                onPressed: () => context.go('/'),
                child: Text(S.of(context)!.cancel),
              ),
              TextButton(
                onPressed: () {
                  // Perform the required action
                  Navigator.of(context).pop();
                },
                child: Text(S.of(context)!.ok),
              ),
            ],
          ),
        );
      }
    });
    return child;
  }
}
