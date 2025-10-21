import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as mostro;
import 'package:mostro_mobile/features/notifications/notifiers/notification_temporary_state.dart';
import 'package:mostro_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:mostro_mobile/features/notifications/utils/notification_message_mapper.dart';

class CantDoNotificationMapper {
  static final _logger = Logger();
  
  static final _messageMap = <String, String Function(BuildContext)>{
    'pending_order_exists': (context) => S.of(context)!.pendingOrderExists,
    'not_allowed_by_status': (context) => S.of(context)!.notAllowedByStatus,
    'invalid_invoice': (context) => S.of(context)!.invalidInvoice,
    'invalid_trade_index': (context) => S.of(context)!.invalidTradeIndex,
    'is_not_your_order': (context) => S.of(context)!.isNotYourOrder,
    'invalid_signature': (context) => S.of(context)!.invalidSignature,
    'invalid_peer': (context) => S.of(context)!.invalidPeer,
    'invalid_pubkey': (context) => S.of(context)!.invalidPubkey,
    'order_already_canceled': (context) => S.of(context)!.orderAlreadyCanceled,
    'out_of_range_sats_amount': (context) => S.of(context)!.outOfRangeSatsAmount,
    'cant_create_user': (context) => S.of(context)!.cantCreateUser,
    'out_of_range_fiat_amount': (context) => S.of(context)!.outOfRangeFiatAmount,
    'invalid_amount': (context) => S.of(context)!.invalidAmount,
    'invalid_rating': (context) => S.of(context)!.invalidRating,
    'invalid_order_kind': (context) => S.of(context)!.invalidOrderKind,
    'invalid_order_status': (context) => S.of(context)!.invalidOrderStatus,
    'invalid_fiat_currency': (context) => S.of(context)!.invalidFiatCurrency,
  };
  
  static String getMessage(BuildContext context, String cantDoReason) {
    final messageGetter = _messageMap[cantDoReason];
    if (messageGetter != null) {
      return messageGetter(context);
    }
    
    _logger.w('Unhandled cant-do reason: $cantDoReason. Consider adding to CantDoNotificationMapper.');
    
    // Fallback to generic cant-do message
    return NotificationMessageMapper.getLocalizedTitle(context, mostro.Action.cantDo);
  }
}


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
            case 'sessionTimeoutMessage':
              message = S.of(context)!.sessionTimeoutMessage;
              break;
            default:
              message = next.customMessage!;
          }
        } else if (next.action != null) {
          // Handle specific cant-do reasons with custom messages
          if (next.action == mostro.Action.cantDo) {
            final reason = next.values['reason'];
            if (reason is String && reason.isNotEmpty) {
              message = CantDoNotificationMapper.getMessage(context, reason);
            } else {
              // Fallback if the payload is malformed or type changes
              message = NotificationMessageMapper.getLocalizedTitle(context, mostro.Action.cantDo);
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
