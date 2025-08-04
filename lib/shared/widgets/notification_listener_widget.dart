import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/features/notifications/notifiers/notification_temporary_state.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:mostro_mobile/features/notifications/utils/notification_message_mapper.dart';

// Helper function to resolve notification keys to localized text
String _resolveNotificationText(BuildContext context, String key) {
  final s = S.of(context)!;
  
  // Simple resolver for common notification titles used in SnackBars
  switch (key) {
    case 'notification_new_order_title':
      return s.notification_new_order_title;
    case 'notification_order_taken_title':
      return s.notification_order_taken_title;
    case 'notification_payment_required_title':
      return s.notification_payment_required_title;
    case 'notification_fiat_sent_title':
      return s.notification_fiat_sent_title;
    case 'notification_fiat_sent_ok_title':
      return s.notification_fiat_sent_ok_title;
    case 'notification_bitcoin_released_title':
      return s.notification_bitcoin_released_title;
    case 'notification_dispute_started_title':
      return s.notification_dispute_started_title;
    case 'notification_order_canceled_title':
      return s.notification_order_canceled_title;
    case 'notification_new_message_title':
      return s.notification_new_message_title;
    case 'notification_cant_do_title':
      return s.notification_cant_do_title;
    case 'notification_payment_failed_title':
      return s.notification_payment_failed_title;
    case 'notification_buyer_took_order_title':
      return s.notification_buyer_took_order_title;
    case 'notification_purchase_completed_title':
      return s.notification_purchase_completed_title;
    case 'notification_cooperative_cancel_initiated_by_you_title':
      return s.notification_cooperative_cancel_initiated_by_you_title;
    case 'notification_cooperative_cancel_initiated_by_peer_title':
      return s.notification_cooperative_cancel_initiated_by_peer_title;
    default:
      return s.notification_order_update_title;
  }
}

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
          // Get the title key and resolve it to localized text
          final titleKey = NotificationMessageMapper.getTitleKey(next.action!);
          message = _resolveNotificationText(context, titleKey);
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
