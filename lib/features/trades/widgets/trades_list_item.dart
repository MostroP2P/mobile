import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/time_provider.dart';
import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';
import 'package:mostro_mobile/shared/utils/currency_utils.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class TradesListItem extends ConsumerWidget {
  final NostrEvent trade;

  const TradesListItem({super.key, required this.trade});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(timeProvider);
    final currencyData = ref.watch(currencyCodesProvider).asData?.value;
    final session = ref.watch(sessionProvider(trade.orderId!));
    final role = session?.role;
    final isBuying = role == Role.buyer;
    final orderState = ref.watch(orderNotifierProvider(trade.orderId!));

    // Determine if the user is the creator of the order based on role and order type
    final isCreator = isBuying
        ? trade.orderType == OrderType.buy
        : trade.orderType == OrderType.sell;

    return GestureDetector(
      onTap: () {
        context.push('/trade_detail/${trade.orderId}');
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(

          color: AppTheme.dark1,

          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left side - Trade info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // First row: Buy/Sell Bitcoin text (full width)
                    Text(
                      isBuying
                          ? S.of(context)!.buyingBitcoin
                          : S.of(context)!.sellingBitcoin,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Second row: Status and role chips + Premium/Discount
                    Row(
                      children: [
                        _buildStatusChip(context, orderState.status),
                        const SizedBox(width: 8),
                        _buildRoleChip(context, isCreator),
                        const Spacer(),
                        // Show premium/discount if different from zero
                        if (trade.premium != null && trade.premium != '0')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  double.tryParse(trade.premium!) != null &&
                                          double.parse(trade.premium!) > 0
                                      ? AppTheme.premiumPositiveChip
                                      : AppTheme.premiumNegativeChip,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${double.tryParse(trade.premium!) != null && double.parse(trade.premium!) > 0 ? '+' : ''}${trade.premium}%',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Third row: Flag + Amount and currency
                    Row(
                      children: [
                        Text(
                          CurrencyUtils.getFlagFromCurrencyData(
                              trade.currency ?? '', currencyData),
                          style: const TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            trade.fiatAmount.maximum != null &&
                                    trade.fiatAmount.maximum !=
                                        trade.fiatAmount.minimum
                                ? '${trade.fiatAmount.minimum} - ${trade.fiatAmount.maximum} ${trade.currency ?? ''}'
                                : '${trade.fiatAmount.minimum} ${trade.currency ?? ''}',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    trade.paymentMethods.isNotEmpty
                        ? Text(
                            trade.paymentMethods.join(', '),
                            style: const TextStyle(
                              color: AppTheme.secondaryText,
                              fontSize: 14,
                            ),
                          )
                        : Text(
                            S.of(context)!.bankTransfer,
                            style: const TextStyle(
                              color: AppTheme.secondaryText,
                              fontSize: 14,
                            ),
                          ),
                  ],
                ),
              ),
              // Right side - Arrow icon
              const Icon(
                Icons.chevron_right,
                color: AppTheme.textPrimary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(BuildContext context, bool isCreator) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(

        color: isCreator ? AppTheme.createdByYouChip : AppTheme.takenByYouChip,
        borderRadius: BorderRadius.circular(12),

      ),
      child: Text(
        isCreator ? S.of(context)!.createdByYou : S.of(context)!.takenByYou,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
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
        label = S.of(context)!.cancel;
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
}
