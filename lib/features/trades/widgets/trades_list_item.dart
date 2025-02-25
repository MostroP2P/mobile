import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';
import 'package:mostro_mobile/shared/utils/currency_utils.dart';

class TradesListItem extends StatelessWidget {
  final NostrEvent trade;

  const TradesListItem({super.key, required this.trade});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.go('/trade_detail/${trade.orderId}');
      },
      child: CustomCard(
        color: AppTheme.dark1,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildSessionDetails(context),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${toBeginningOfSentenceCase(trade.status)}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.cream1,
              ),
        ),
        Text(
          'Time: ${trade.expiration}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.cream1,
              ),
        ),
      ],
    );
  }

  Widget _buildSessionDetails(BuildContext context) {
    return Row(
      children: [
        _getOrderOffering(context, trade),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: _buildPaymentMethod(context),
        ),
      ],
    );
  }

  Widget _getOrderOffering(BuildContext context, NostrEvent trade) {
    String offering = trade.orderType == OrderType.buy ? 'Selling' : 'Buying';
    String amountText = (trade.amount != null && trade.amount != '0')
        ? ' ${trade.amount!}'
        : '';

    return Expanded(
      flex: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                _buildStyledTextSpan(
                  context,
                  offering,
                  amountText,
                  isValue: true,
                  isBold: true,
                ),
                TextSpan(
                  text: 'sats',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.cream1,
                        fontWeight: FontWeight.normal,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8.0),
          RichText(
            text: TextSpan(
              children: [
                _buildStyledTextSpan(
                  context,
                  'for ',
                  '${trade.fiatAmount}',
                  isValue: true,
                  isBold: true,
                ),
                TextSpan(
                  text:
                      '${trade.currency} ${CurrencyUtils.getFlagFromCurrency(trade.currency!)} ',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.cream1,
                        fontSize: 16.0,
                      ),
                ),
                TextSpan(
                  text: '(${trade.premium}%)',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.cream1,
                        fontSize: 16.0,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod(BuildContext context) {
    String method = trade.paymentMethods.isNotEmpty
        ? trade.paymentMethods[0]
        : 'No payment method';

    return Row(
      children: [
        HeroIcon(
          _getPaymentMethodIcon(method),
          style: HeroIconStyle.outline,
          color: AppTheme.cream1,
          size: 16,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            method,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.grey2,
                ),
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
        ),
      ],
    );
  }

  HeroIcons _getPaymentMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'wire transfer':
      case 'transferencia bancaria':
        return HeroIcons.buildingLibrary;
      case 'revolut':
        return HeroIcons.creditCard;
      default:
        return HeroIcons.banknotes;
    }
  }

  TextSpan _buildStyledTextSpan(
    BuildContext context,
    String label,
    String value, {
    bool isValue = false,
    bool isBold = false,
  }) {
    return TextSpan(
      text: label,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppTheme.cream1,
            fontWeight: FontWeight.normal,
            fontSize: isValue ? 16.0 : 24.0,
          ),
      children: isValue
          ? [
              TextSpan(
                text: '$value ',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                      fontSize: 24.0,
                      color: AppTheme.cream1,
                    ),
              ),
            ]
          : [],
    );
  }
}
