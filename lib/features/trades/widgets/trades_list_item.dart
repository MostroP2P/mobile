import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/shared/providers/session_manager_provider.dart';
import 'package:mostro_mobile/shared/providers/time_provider.dart';
import 'package:mostro_mobile/shared/utils/currency_utils.dart';

class TradesListItem extends ConsumerWidget {
  final NostrEvent trade;

  const TradesListItem({super.key, required this.trade});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(timeProvider);
    final session = ref.watch(sessionProvider(trade.orderId!));
    final role = session?.role;
    final isBuying = role == Role.buyer;

    return GestureDetector(
      onTap: () {
        context.push('/trade_detail/${trade.orderId}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        decoration: BoxDecoration(
          color: AppTheme.dark1,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade900, width: 1),
          ),
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
                    // First row: Buy/Sell Bitcoin + Status
                    Row(
                      children: [
                        Text(
                          isBuying ? 'Buying Bitcoin' : 'Selling Bitcoin',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusChip(trade.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Second row: Amount and currency
                    Row(
                      children: [
                        Text(
                          '${isBuying ? trade.currency : trade.amount} ${CurrencyUtils.getFlagFromCurrency(trade.currency!)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Third row: Payment method
                    Text(
                      trade.paymentMethods.isNotEmpty
                          ? trade.paymentMethods.first
                          : 'Bank Transfer',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Right side - Arrow icon
              const Icon(
                Icons.chevron_right,
                color: Colors.white,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(Status status) {
    Color backgroundColor;
    Color textColor = Colors.white;
    String label;

    switch (status) {
      case Status.active:
        backgroundColor = Colors.blue;
        label = 'Active';
        break;
      case Status.pending:
        backgroundColor = Colors.amber.shade800;
        label = 'Pending';
        break;
      case Status.fiatSent:
        backgroundColor = Colors.green.shade700;
        label = 'Fiat-sent';
        break;
      case Status.canceled:
      case Status.canceledByAdmin:
      case Status.cooperativelyCanceled:
        backgroundColor = Colors.grey.shade700;
        label = 'Canceled';
        break;
      case Status.settledByAdmin:
      case Status.settledHoldInvoice:
        backgroundColor = Colors.purple;
        label = 'Settled';
        break;
      case Status.completedByAdmin:
        backgroundColor = Colors.green;
        label = 'Completed';
        break;
      case Status.dispute:
        backgroundColor = Colors.red;
        label = 'Dispute';
        break;
      case Status.expired:
        backgroundColor = Colors.grey;
        label = 'Expired';
        break;
      case Status.success:
        backgroundColor = Colors.green;
        label = 'Success';
        break;
      case Status.waitingBuyerInvoice:
        backgroundColor = Colors.blue.shade300;
        label = 'Waiting Invoice';
        break;
      case Status.waitingPayment:
        backgroundColor = Colors.blue.shade400;
        label = 'Waiting Payment';
        break;
      case Status.inProgress:
        backgroundColor = Colors.blue.shade700;
        label = 'In Progress';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
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
