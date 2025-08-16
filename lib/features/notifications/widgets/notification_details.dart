import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/notification.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as mostro_action;
import 'package:mostro_mobile/features/notifications/widgets/detail_row.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class NotificationDetails extends StatelessWidget {
  final NotificationModel notification;

  const NotificationDetails({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppTheme.smallPadding,
      decoration: BoxDecoration(
        color: AppTheme.backgroundInput.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.textInactive.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildDetailsWidgets(context),
      ),
    );
  }

  List<Widget> _buildDetailsWidgets(BuildContext context) {
    final widgets = <Widget>[];
    final data = notification.data;

    switch (notification.action) {
      case mostro_action.Action.fiatSentOk:
        if (data.containsKey('buyer_npub')) {
          widgets.add(DetailRow(
            label: S.of(context)!.notificationBuyer,
            value: _formatHashOrId(data['buyer_npub']),
            icon: HeroIcons.user,
          ));
        }
        break;

      case mostro_action.Action.holdInvoicePaymentAccepted:
        if (data.containsKey('seller_npub')) {
          widgets.add(DetailRow(
            label: S.of(context)!.notificationSeller,
            value: _formatHashOrId(data['seller_npub']),
            icon: HeroIcons.user,
          ));
        }
        if (data.containsKey('fiat_amount') && data.containsKey('fiat_code')) {
          widgets.add(DetailRow(
            label: S.of(context)!.notificationAmount,
            value: '${data['fiat_amount']} ${data['fiat_code']}',
            icon: HeroIcons.banknotes,
          ));
        }
        if (data.containsKey('payment_method')) {
          widgets.add(DetailRow(
            label: S.of(context)!.notificationPaymentMethod,
            value: data['payment_method'].toString(),
            icon: HeroIcons.creditCard,
          ));
        }
        break;

      case mostro_action.Action.waitingSellerToPay:
      case mostro_action.Action.waitingBuyerInvoice:
        if (data.containsKey('expiration_seconds')) {
          final expirationSeconds = data['expiration_seconds'];
          final expirationMinutes = (expirationSeconds is int ? expirationSeconds : int.tryParse(expirationSeconds.toString()) ?? 0) ~/ 60;
          widgets.add(DetailRow(
            label: S.of(context)!.notificationTimeout,
            value: '$expirationMinutes ${S.of(context)!.notificationMinutes}',
            icon: HeroIcons.clock,
          ));
        }
        break;

      case mostro_action.Action.disputeInitiatedByYou:
      case mostro_action.Action.disputeInitiatedByPeer:
        if (data.containsKey('user_token')) {
          widgets.add(DetailRow(
            label: S.of(context)!.notificationDisputeId,
            value: _formatHashOrId(data['user_token'].toString()),
            icon: HeroIcons.exclamationTriangle,
          ));
        }
        break;

      case mostro_action.Action.paymentFailed:
        if (data.containsKey('payment_attempts')) {
          widgets.add(DetailRow(
            label: S.of(context)!.notificationAttempts,
            value: data['payment_attempts'].toString(),
            icon: HeroIcons.arrowPath,
          ));
        }
        if (data.containsKey('payment_retries_interval')) {
          widgets.add(DetailRow(
            label: S.of(context)!.notificationRetryInterval,
            value: '${data['payment_retries_interval']}s',
            icon: HeroIcons.clock,
          ));
        }
        break;

      case mostro_action.Action.cantDo:
        if (data.containsKey('action')) {
          widgets.add(DetailRow(
            label: S.of(context)!.notificationReason,
            value: data['action'].toString(),
            icon: HeroIcons.xMark,
          ));
        }
        break;

      case mostro_action.Action.released:
        if (data.containsKey('seller_npub') && data['seller_npub'].toString().isNotEmpty) {
          widgets.add(DetailRow(
            label: S.of(context)!.notificationSeller,
            value: _formatHashOrId(data['seller_npub']),
            icon: HeroIcons.user,
          ));
        }
        break;

      case mostro_action.Action.holdInvoicePaymentSettled:
        if (data.containsKey('buyer_npub') && data['buyer_npub'].toString().isNotEmpty) {
          widgets.add(DetailRow(
            label: S.of(context)!.notificationBuyer,
            value: _formatHashOrId(data['buyer_npub']),
            icon: HeroIcons.user,
          ));
        }
        break;

      case mostro_action.Action.canceled:
        if (data.containsKey('id')) {
          widgets.add(DetailRow(
            label: S.of(context)!.notificationOrderId,
            value: _formatHashOrId(data['id'].toString()),
            icon: HeroIcons.hashtag,
          ));
        }
        break;

      case mostro_action.Action.cooperativeCancelInitiatedByYou:
      case mostro_action.Action.cooperativeCancelInitiatedByPeer:
      case mostro_action.Action.cooperativeCancelAccepted:
        if (data.containsKey('id')) {
          widgets.add(DetailRow(
            label: S.of(context)!.notificationOrderId,
            value: _formatHashOrId(data['id'].toString()),
            icon: HeroIcons.hashtag,
          ));
        }
        break;

      default:
        // TODO: Add specific handler for ${notification.action}
        // No data displayed for unhandled actions to prevent information exposure
        break;
    }

    return widgets;
  }

  String _formatHashOrId(String value) {
    if (value.isEmpty) return 'N/A';
    
    if (value.length <= 8) {
      return value; // Show full value if it's short enough
    }
    
    String start = value.substring(0, 8);
    String end = value.substring(value.length - 5);
    
    return '$start...$end';
  }

}