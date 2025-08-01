import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/features/notifications/notifiers/notifications_notifier.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as mostro_action;

// Helper function to get localized text for SnackBar
String _getSnackBarText(BuildContext context, mostro_action.Action action) {
  final s = S.of(context)!;
  
  switch (action) {
    case mostro_action.Action.newOrder:
      return s.notification_new_order_title;
    case mostro_action.Action.takeBuy:
    case mostro_action.Action.takeSell:
      return s.notification_order_taken_title;
    case mostro_action.Action.payInvoice:
      return s.notification_payment_required_title;
    case mostro_action.Action.fiatSent:
      return s.notification_fiat_sent_title;
    case mostro_action.Action.released:
      return s.notification_bitcoin_released_title;
    case mostro_action.Action.dispute:
      return s.notification_dispute_started_title;
    case mostro_action.Action.canceled:
      return s.notification_order_canceled_title;
    case mostro_action.Action.sendDm:
      return s.notification_new_message_title;
    default:
      return s.notification_order_update_title;
  }
}

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
            content: Text(_getSnackBarText(context, next.action!)),
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
