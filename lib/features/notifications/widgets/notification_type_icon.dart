import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/data/models/enums/notification_type.dart';

class NotificationTypeIcon extends StatelessWidget {
  final NotificationType type;
  final actions.Action action;

  const NotificationTypeIcon({
    super.key,
    required this.type,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = _getIconForType();
    final iconColor = _getColorForType();

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: HeroIcon(
          iconData.icon,
          style: iconData.style,
          size: 20,
          color: iconColor,
        ),
      ),
    );
  }

  _IconData _getIconForType() {
    switch (type) {
      case NotificationType.orderUpdate:
        return _IconData(HeroIcons.plus, HeroIconStyle.outline);
      
      case NotificationType.tradeUpdate:
        switch (action) {
          case actions.Action.buyerTookOrder:
            return _IconData(HeroIcons.handRaised, HeroIconStyle.outline);
          case actions.Action.rate:
          case actions.Action.rateUser:
          case actions.Action.rateReceived:
            return _IconData(HeroIcons.star, HeroIconStyle.outline);
          default:
            return _IconData(HeroIcons.arrowsRightLeft, HeroIconStyle.outline);
        }
      
      case NotificationType.payment:
        switch (action) {
          case actions.Action.payInvoice:
          case actions.Action.waitingSellerToPay:
            return _IconData(HeroIcons.creditCard, HeroIconStyle.outline);
          case actions.Action.fiatSent:
          case actions.Action.fiatSentOk:
            return _IconData(HeroIcons.banknotes, HeroIconStyle.outline);
          case actions.Action.release:
          case actions.Action.released:
          case actions.Action.purchaseCompleted:
            return _IconData(HeroIcons.checkCircle, HeroIconStyle.outline);
          case actions.Action.paymentFailed:
            return _IconData(HeroIcons.xCircle, HeroIconStyle.outline);
          default:
            return _IconData(HeroIcons.currencyDollar, HeroIconStyle.outline);
        }
      
      case NotificationType.dispute:
        return _IconData(HeroIcons.exclamationTriangle, HeroIconStyle.outline);
      
      case NotificationType.cancellation:
        return _IconData(HeroIcons.xCircle, HeroIconStyle.outline);
      
      case NotificationType.message:
        return _IconData(HeroIcons.chatBubbleLeft, HeroIconStyle.outline);
      
      case NotificationType.system:
        return _IconData(HeroIcons.informationCircle, HeroIconStyle.outline);
    }
  }

  Color _getColorForType() {
    switch (type) {
      case NotificationType.orderUpdate:
        return AppTheme.mostroGreen;
      
      case NotificationType.tradeUpdate:
        switch (action) {
          case actions.Action.rate:
          case actions.Action.rateUser:
          case actions.Action.rateReceived:
            return AppTheme.statusWarning;
          default:
            return AppTheme.activeColor;
        }
      
      case NotificationType.payment:
        switch (action) {
          case actions.Action.release:
          case actions.Action.released:
          case actions.Action.purchaseCompleted:
          case actions.Action.fiatSentOk:
            return AppTheme.statusSuccess;
          case actions.Action.paymentFailed:
            return AppTheme.statusError;
          default:
            return AppTheme.statusInfo;
        }
      
      case NotificationType.dispute:
        return AppTheme.statusError;
      
      case NotificationType.cancellation:
        return AppTheme.statusError;
      
      case NotificationType.message:
        return AppTheme.statusInfo;
      
      case NotificationType.system:
        return AppTheme.textSecondary;
    }
  }
}

class _IconData {
  final HeroIcons icon;
  final HeroIconStyle style;

  const _IconData(this.icon, this.style);
}