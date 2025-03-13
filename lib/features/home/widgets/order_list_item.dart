import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/shared/providers/time_provider.dart';
import 'package:mostro_mobile/shared/utils/currency_utils.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';

class OrderListItem extends ConsumerWidget {
  final NostrEvent order;

  const OrderListItem({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(timeProvider);

    return GestureDetector(
      onTap: () {
        order.orderType == OrderType.buy
            ? context.push('/take_buy/${order.orderId}')
            : context.push('/take_sell/${order.orderId}');
      },
      child: CustomCard(
        color: AppTheme.dark1,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(order.orderType == OrderType.buy ? 'buying' : 'selling'),
                Text('${order.expiration}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _getOrderOffering(context, order),
                const SizedBox(width: 16),
              ],
            ),
            const SizedBox(height: 8),
            _buildPaymentMethod(context),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                    '${order.rating?.totalRating ?? 0.0} ${getStars(order.rating?.totalRating ?? 0.0)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _getOrderOffering(BuildContext context, NostrEvent order) {
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
                  '    ',
                  '${order.fiatAmount}',
                  isValue: true,
                  isBold: true,
                ),
                TextSpan(
                  text:
                      '${order.currency} ${CurrencyUtils.getFlagFromCurrency(order.currency!)} ',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.cream1,
                        fontSize: 16.0,
                      ),
                ),
                TextSpan(
                  text: '(${order.premium}%)',
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
    String method = order.paymentMethods.isNotEmpty
        ? order.paymentMethods[0]
        : 'No payment method';

    String methods = order.paymentMethods.join('\n');

    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: HeroIcon(
            _getPaymentMethodIcon(method),
            style: HeroIconStyle.outline,
            color: AppTheme.cream1,
            size: 16,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            methods,
            style: AppTheme.theme.textTheme.bodySmall,
            overflow: TextOverflow.fade,
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

  String getStars(double count) {
    return count > 0 ? '⭐' * count.toInt() : '';
  }
}
