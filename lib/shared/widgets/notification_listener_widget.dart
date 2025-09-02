import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as mostro;
import 'package:mostro_mobile/features/notifications/notifiers/notification_temporary_state.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:mostro_mobile/features/notifications/utils/notification_message_mapper.dart';


class NotificationListenerWidget extends ConsumerWidget {
  final Widget child;

  const NotificationListenerWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<TemporaryNotification>(currentTemporaryNotificationProvider, (previous, next) {
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
        } else if (next.action != null) {
          // Handle specific cant-do reasons with custom messages
          if (next.action == mostro.Action.cantDo && next.values['action'] != null) {
            final cantDoReason = next.values['action'] as String?;
            if (cantDoReason != null && cantDoReason == 'pending_order_exists') {
              message = S.of(context)!.pendingOrderExists;
            } else if (cantDoReason != null && cantDoReason == 'not_allowed_by_status') {
              message = S.of(context)!.notAllowedByStatus;
            } else if (cantDoReason != null && cantDoReason == 'invalid_invoice') {
              message = S.of(context)!.invalidInvoice;
            } else if (cantDoReason != null && cantDoReason == 'invalid_trade_index') {
              message = S.of(context)!.invalidTradeIndex;
            } else if (cantDoReason != null && cantDoReason == 'is_not_your_order') {
              message = S.of(context)!.isNotYourOrder;
            } else if (cantDoReason != null && cantDoReason == 'invalid_signature') {
              message = S.of(context)!.invalidSignature;
            } else if (cantDoReason != null && cantDoReason == 'invalid_peer') {
              message = S.of(context)!.invalidPeer;
            } else if (cantDoReason != null && cantDoReason == 'invalid_pubkey') {
              message = S.of(context)!.invalidPubkey;
            } else if (cantDoReason != null && cantDoReason == 'order_already_canceled') {
              message = S.of(context)!.orderAlreadyCanceled;
            } else if (cantDoReason != null && cantDoReason == 'out_of_range_sats_amount') {
              message = S.of(context)!.outOfRangeSatsAmount;
            } else {
              // Use generic cant-do message for other reasons
              message = NotificationMessageMapper.getLocalizedTitle(context, next.action!);
            }
          } else {
            // Get localized title directly from action when available
            message = NotificationMessageMapper.getLocalizedTitle(context, next.action!);
          }
        } else {
          // Fallback to generic notification title when no action or custom message
          message = S.of(context)!.notificationGenericTitle;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2), // Show for 2 seconds
          ),
        );
        // Clear notification after showing to prevent repetition
        ref.read(notificationActionsProvider.notifier).clearTemporary();
      }
    });
    return child;
  }
}
