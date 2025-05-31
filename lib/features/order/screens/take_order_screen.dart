import 'package:circular_countdown/circular_countdown.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/utils/currency_utils.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';

class TakeOrderScreen extends ConsumerWidget {
  final String orderId;
  final OrderType orderType;
  final TextEditingController _fiatAmountController = TextEditingController();
  final TextEditingController _lndAddressController = TextEditingController();
  final TextTheme textTheme = AppTheme.theme.textTheme;

  TakeOrderScreen({super.key, required this.orderId, required this.orderType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(eventProvider(orderId));

    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: OrderAppBar(title: 'ORDER DETAILS'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildSellerAmount(ref, order!),
            const SizedBox(height: 16),
            _buildOrderId(context),
            const SizedBox(height: 24),
            _buildCountDownTime(order.expirationDate),
            const SizedBox(height: 36),
            // Pass the full order to the action buttons widget.
            _buildActionButtons(context, ref, order),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerAmount(WidgetRef ref, NostrEvent order) {
    final selling = orderType == OrderType.sell ? 'selling' : 'buying';
    final amountString =
        '${order.fiatAmount} ${order.currency} ${CurrencyUtils.getFlagFromCurrency(order.currency!)}';
    final satAmount = order.amount == '0' ? '' : ' ${order.amount}';
    final price = order.amount != '0' ? '' : 'at market price';
    final premium = int.parse(order.premium ?? '0');
    final premiumText = premium >= 0
        ? premium == 0
            ? ''
            : 'with a +$premium% premium'
        : 'with a -$premium% discount';
    final method = order.paymentMethods.isNotEmpty
        ? order.paymentMethods[0]
        : 'No payment method';

    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              spacing: 2,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Someone is $selling$satAmount sats for $amountString $price $premiumText',
                  style: AppTheme.theme.textTheme.bodyLarge,
                  softWrap: true,
                ),
                const SizedBox(height: 16),
                Text(
                  'Created on: ${formatDateTime(order.createdAt!)}',
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  'The payment method is: $method',
                  style: textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderId(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SelectableText(
            orderId,
            style: TextStyle(color: AppTheme.mostroGreen),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: orderId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Order ID copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy),
            style: IconButton.styleFrom(
              foregroundColor: AppTheme.mostroGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCountDownTime(DateTime expiration) {
    Duration countdown = Duration(hours: 0);
    final now = DateTime.now();
    if (expiration.isAfter(now)) {
      countdown = expiration.difference(now);
    }

    return Column(
      children: [
        CircularCountdown(
          countdownTotal: 24,
          countdownRemaining: countdown.inHours,
        ),
        const SizedBox(height: 16),
        Text('Time Left: ${countdown.toString().split('.')[0]}'),
      ],
    );
  }

  Widget _buildActionButtons(
      BuildContext context, WidgetRef ref, NostrEvent order) {
    final orderDetailsNotifier = ref.read(
      orderNotifierProvider(order.orderId!).notifier,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton(
          onPressed: () {
            context.pop();
          },
          style: AppTheme.theme.outlinedButtonTheme.style,
          child: const Text('CLOSE'),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: () async {
            // Check if the order is a range order.
            if (order.fiatAmount.maximum != null) {
              final enteredAmount = await showDialog<int>(
                context: context,
                builder: (BuildContext context) {
                  String? errorText;
                  return StatefulBuilder(
                    builder: (BuildContext context,
                        void Function(void Function()) setState) {
                      return AlertDialog(
                        title: const Text('Enter Amount'),
                        content: TextField(
                          controller: _fiatAmountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText:
                                'Enter an amount between ${order.fiatAmount.minimum} and ${order.fiatAmount.maximum}',
                            errorText: errorText,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(null),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              final inputAmount = int.tryParse(
                                  _fiatAmountController.text.trim());
                              if (inputAmount == null) {
                                setState(() {
                                  errorText = "Please enter a valid number.";
                                });
                              } else if (inputAmount <
                                      order.fiatAmount.minimum ||
                                  inputAmount > order.fiatAmount.maximum!) {
                                setState(() {
                                  errorText =
                                      "Amount must be between ${order.fiatAmount.minimum} and ${order.fiatAmount.maximum}.";
                                });
                              } else {
                                Navigator.of(context).pop(inputAmount);
                              }
                            },
                            child: const Text('Submit'),
                          ),
                        ],
                      );
                    },
                  );
                },
              );

              if (enteredAmount != null) {
                if (orderType == OrderType.buy) {
                  await orderDetailsNotifier.takeBuyOrder(
                      order.orderId!, enteredAmount);
                } else {
                  final lndAddress = _lndAddressController.text.trim();
                  await orderDetailsNotifier.takeSellOrder(
                    order.orderId!,
                    enteredAmount,
                    lndAddress.isEmpty ? null : lndAddress,
                  );
                }
              }
            } else {
              // Not a range order – use the existing logic.
              final fiatAmount =
                  int.tryParse(_fiatAmountController.text.trim());
              if (orderType == OrderType.buy) {
                await orderDetailsNotifier.takeBuyOrder(
                    order.orderId!, fiatAmount);
              } else {
                final lndAddress = _lndAddressController.text.trim();
                await orderDetailsNotifier.takeSellOrder(
                  order.orderId!,
                  fiatAmount,
                  lndAddress.isEmpty ? null : lndAddress,
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.mostroGreen,
          ),
          child: const Text('TAKE'),
        ),
      ],
    );
  }

  String formatDateTime(DateTime dt) {
    final dateFormatter = DateFormat('EEE MMM dd yyyy HH:mm:ss');
    final formattedDate = dateFormatter.format(dt);
    final offset = dt.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final timeZoneName = dt.timeZoneName;
    return '$formattedDate GMT $sign$hours$minutes ($timeZoneName)';
  }
}
