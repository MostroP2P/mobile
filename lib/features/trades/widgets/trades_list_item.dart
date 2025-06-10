import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/time_provider.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';
import 'package:mostro_mobile/shared/utils/currency_utils.dart';

class TradesListItem extends ConsumerWidget {
  final NostrEvent trade;

  const TradesListItem({super.key, required this.trade});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(timeProvider);

    return GestureDetector(
      onTap: () {
        context.push('/trade_detail/${trade.orderId}');
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
            _buildSessionDetails(context, ref),
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
        _buildStatusChip(trade.status),
        Text(
          '${trade.expiration}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.cream1,
              ),
        ),
      ],
    );
  }

  Widget _buildSessionDetails(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider(trade.orderId!));
    return Row(
      children: [
        _getOrderOffering(context, trade, session!.role),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: _buildPaymentMethod(context),
        ),
      ],
    );
  }

  Widget _getOrderOffering(
    BuildContext context,
    NostrEvent trade,
    Role? role,
  ) {
    String offering = role == Role.buyer ? 'Buying' : 'Selling';
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

  Widget _buildStatusChip(Status status) {
    Color backgroundColor;
    Color textColor = AppTheme.cream1;
    String label;

    switch (status) {
      case Status.active:
        backgroundColor = AppTheme.red1;
        label = 'Active';
        break;
      case Status.canceled:
        backgroundColor = AppTheme.grey;
        label = 'Canceled';
        break;
      case Status.canceledByAdmin:
        backgroundColor = AppTheme.red2;
        label = 'Canceled by Admin';
        break;
      case Status.settledByAdmin:
        backgroundColor = AppTheme.yellow;
        label = 'Settled by Admin';
        break;
      case Status.completedByAdmin:
        backgroundColor = AppTheme.grey2;
        label = 'Completed by Admin';
        break;
      case Status.dispute:
        backgroundColor = AppTheme.red1;
        label = 'Dispute';
        break;
      case Status.expired:
        backgroundColor = AppTheme.grey;
        label = 'Expired';
        break;
      case Status.fiatSent:
        backgroundColor = Colors.indigo;
        label = 'Fiat Sent';
        break;
      case Status.settledHoldInvoice:
        backgroundColor = Colors.teal;
        label = 'Settled Hold Invoice';
        break;
      case Status.pending:
        backgroundColor = AppTheme.mostroGreen;
        textColor = Colors.black;
        label = 'Pending';
        break;
      case Status.success:
        backgroundColor = Colors.green;
        label = 'Success';
        break;
      case Status.waitingBuyerInvoice:
        backgroundColor = Colors.lightBlue;
        label = 'Waiting Buyer Invoice';
        break;
      case Status.waitingPayment:
        backgroundColor = Colors.lightBlueAccent;
        label = 'Waiting Payment';
        break;
      case Status.cooperativelyCanceled:
        backgroundColor = Colors.deepOrange;
        label = 'Cooperatively Canceled';
        break;
      case Status.inProgress:
        backgroundColor = Colors.blueGrey;
        label = 'In Progress';
        break;
    }

    return Chip(
      backgroundColor: backgroundColor,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4.0),
        side: BorderSide.none,
      ),
      label: Text(
        label,
        style: TextStyle(color: textColor, fontSize: 12.0),
      ),
    );
  }
}
