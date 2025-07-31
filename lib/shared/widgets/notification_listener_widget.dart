import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    ref.listen<NotificationTemporaryState>(temporaryNotificationProvider, (previous, next) {
      if (next.show && next.action != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getSnackBarText(context, next.action!)),
          ),
        );
        // Clear notification after showing to prevent repetition
        ref.read(notificationsProvider.notifier).clearTemporary();
      }
    });
    return child;
  }
}
