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
      appBar: OrderAppBar(
          title: orderType == OrderType.buy
              ? 'BUY ORDER DETAILS'
              : 'SELL ORDER DETAILS'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildSellerAmount(ref, order!),
            const SizedBox(height: 16),
            _buildPaymentMethod(order),
            const SizedBox(height: 16),
            _buildCreatedOn(order),
            const SizedBox(height: 16),
            _buildOrderId(context),
            const SizedBox(height: 16),
            _buildCreatorReputation(order),
            const SizedBox(height: 24),
            _buildCountDownTime(order.expirationDate),
            const SizedBox(height: 36),
            _buildActionButtons(context, ref, order),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerAmount(WidgetRef ref, NostrEvent order) {
    final selling = orderType == OrderType.sell ? 'Selling' : 'Buying';
    final currencyFlag = CurrencyUtils.getFlagFromCurrency(order.currency!);
    final amountString = '${order.fiatAmount} ${order.currency} $currencyFlag';
    final priceText = order.amount == '0' ? 'at market price' : '';

    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Someone is $selling Sats',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'for $amountString',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              if (priceText.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  priceText,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
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

  Widget _buildPaymentMethod(NostrEvent order) {
    final methods = order.paymentMethods.isNotEmpty
        ? order.paymentMethods.join(', ')
        : 'No payment method';

    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(
            Icons.payment,
            color: Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Method',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  methods,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatedOn(NostrEvent order) {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(
            Icons.schedule,
            color: Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Created On',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatDateTime(order.createdAt!),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatorReputation(NostrEvent order) {
    // For now, show placeholder data matching TradeDetailScreen
    // In a real implementation, this would come from the order creator's data
    const rating = 3.1;
    const reviews = 15;
    const days = 7;

    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Creator\'s Reputation',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Rating section
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.star,
                            color: AppTheme.mostroGreen,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rating',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Reviews section
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            reviews.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reviews',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Days section
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            days.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Days',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, WidgetRef ref, NostrEvent order) {
    final orderDetailsNotifier =
        ref.read(orderNotifierProvider(orderId).notifier);

    final buttonText =
        orderType == OrderType.buy ? 'SELL BITCOIN' : 'BUY BITCOIN';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => context.pop(),
            style: AppTheme.theme.outlinedButtonTheme.style,
            child: const Text('CLOSE'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              // Check if this is a range order
              if (order.fiatAmount.minimum != order.fiatAmount.maximum) {
                // Show dialog to get the amount
                String? errorText;
                final enteredAmount = await showDialog<int>(
                  context: context,
                  builder: (context) {
                    return StatefulBuilder(
                      builder: (context, setState) {
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
                              key: const Key('submitAmountButton'),
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
            child: Text(buttonText),
          ),
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
