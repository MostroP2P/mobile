import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/utils/currency_utils.dart';

class TradeInformationTab extends StatelessWidget {
  final Order? order;
  final String orderId;

  const TradeInformationTab({
    super.key,
    required this.order,
    required this.orderId,
  });

  /// Format order date safely with fallback for null dates
  String _formatOrderDate(DateTime? date, BuildContext context) {
    if (date == null) {
      return S.of(context)!.unknownDate;
    }
    return DateFormat('MMMM d, yyyy').format(date);
  }

  /// Get a valid creation date for the order
  /// Uses order.createdAt if valid, otherwise falls back to current time
  DateTime _getOrderCreationDate() {
    if (order?.createdAt != null && order!.createdAt! > 0) {
      // Convert Unix timestamp to DateTime
      return DateTime.fromMillisecondsSinceEpoch(order!.createdAt! * 1000);
    }
    
    // Fallback: use current time minus a reasonable amount
    // This is better than showing "Unknown date"
    return DateTime.now().subtract(const Duration(hours: 1));
  }

  Widget _buildStatusChip(BuildContext context, Status status) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case Status.active:
        backgroundColor =
            AppTheme.statusActiveBackground.withValues(alpha: 0.3);
        textColor = AppTheme.statusActiveText;
        label = S.of(context)!.active;
        break;
      case Status.pending:
        backgroundColor =
            AppTheme.statusPendingBackground.withValues(alpha: 0.3);
        textColor = AppTheme.statusPendingText;
        label = S.of(context)!.pending;
        break;
      case Status.waitingPayment:
        backgroundColor =
            AppTheme.statusWaitingBackground.withValues(alpha: 0.3);
        textColor = AppTheme.statusWaitingText;
        label = S.of(context)!.waitingPayment;
        break;
      case Status.waitingBuyerInvoice:
        backgroundColor =
            AppTheme.statusWaitingBackground.withValues(alpha: 0.3);
        textColor = AppTheme.statusWaitingText;
        label = S.of(context)!.waitingInvoice;
        break;
      case Status.paymentFailed:
        backgroundColor =
            AppTheme.statusInactiveBackground.withValues(alpha: 0.3);
        textColor = AppTheme.statusInactiveText;
        label = S.of(context)!.paymentFailedText;
        break;
      case Status.fiatSent:
        backgroundColor =
            AppTheme.statusSuccessBackground.withValues(alpha: 0.3);
        textColor = AppTheme.statusSuccessText;
        label = S.of(context)!.fiatSent;
        break;
      case Status.canceled:
      case Status.canceledByAdmin:
      case Status.cooperativelyCanceled:
        backgroundColor =
            AppTheme.statusInactiveBackground.withValues(alpha: 0.3);
        textColor = AppTheme.statusInactiveText;
        label = S.of(context)!.canceledStatus;
        break;
      case Status.settledByAdmin:
        backgroundColor =
            AppTheme.statusSettledBackground.withValues(alpha: 0.3);
        textColor = AppTheme.statusSettledText;
        label = S.of(context)!.settled;
        break;
      case Status.settledHoldInvoice:
        backgroundColor =
            AppTheme.statusPendingBackground.withValues(alpha: 0.3);
        textColor = AppTheme.statusPendingText;
        label = S.of(context)!.statusSettledHoldInvoice;
        break;
      case Status.completedByAdmin:
        backgroundColor =
            AppTheme.statusSuccessBackground.withValues(alpha: 0.3);
        textColor = AppTheme.statusSuccessText;
        label = S.of(context)!.completed;
        break;
      case Status.dispute:
        backgroundColor =
            AppTheme.statusDisputeBackground.withValues(alpha: 0.3);
        textColor = AppTheme.statusDisputeText;
        label = S.of(context)!.dispute;
        break;
      case Status.expired:
        backgroundColor =
            AppTheme.statusInactiveBackground.withValues(alpha: 0.3);
        textColor = AppTheme.statusInactiveText;
        label = S.of(context)!.expired;
        break;
      case Status.success:
        backgroundColor =
            AppTheme.statusSuccessBackground.withValues(alpha: 0.3);
        textColor = AppTheme.statusSuccessText;
        label = S.of(context)!.success;
        break;
      default:
        backgroundColor =
            AppTheme.statusInactiveBackground.withValues(alpha: 0.3);
        textColor = AppTheme.statusInactiveText;
        label = status.toString();
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (order == null) {
      return Center(
        child: CircularProgressIndicator(
          color: AppTheme.mostroGreen,
        ),
      );
    }

    return Container(
      color: AppTheme.backgroundDark,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order ID
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.orderId,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  orderId,
                  style: const TextStyle(
                    color: AppTheme.cream1,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Order details
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        order!.kind.value == 'sell'
                            ? S.of(context)!.sellingSats(CurrencyUtils.formatSats(order!.amount))
                            : S.of(context)!.buyingSats(CurrencyUtils.formatSats(order!.amount)),
                        style: const TextStyle(
                          color: AppTheme.cream1,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusChip(context, order!.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  S.of(context)!.forAmountWithCurrency(order!.fiatAmount.toString(), order!.fiatCode),
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Payment method
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.paymentMethod,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order!.paymentMethod,
                  style: const TextStyle(
                    color: AppTheme.cream1,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Created date
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.createdOn,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatOrderDate(_getOrderCreationDate(), context),
                  style: const TextStyle(
                    color: AppTheme.cream1,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}