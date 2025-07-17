import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/shared/utils/currency_utils.dart';

class TradeInformationTab extends StatelessWidget {
  final Order? order;
  final String orderId;

  const TradeInformationTab({
    super.key,
    required this.order,
    required this.orderId,
  });

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
                  'Order ID:',
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
                    Text(
                      order!.kind.value == 'sell'
                          ? 'Selling ${CurrencyUtils.formatSats(order!.amount)} sats'
                          : 'Buying ${CurrencyUtils.formatSats(order!.amount)} sats',
                      style: const TextStyle(
                        color: AppTheme.cream1,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: order!.status.value == 'active'
                            ? AppTheme.statusActiveBackground
                            : AppTheme.statusPendingBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        order!.status.value.toUpperCase(),
                        style: TextStyle(
                          color: order!.status.value == 'active'
                              ? AppTheme.statusActiveText
                              : AppTheme.statusPendingText,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'for ${order!.fiatAmount} ${order!.fiatCode}',
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
                  'Payment Method:',
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
                  'Created on:',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order!.createdAt != null
                      ? DateFormat('MMMM d, yyyy').format(
                          DateTime.fromMillisecondsSinceEpoch(
                              order!.createdAt! * 1000))
                      : 'Unknown date',
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