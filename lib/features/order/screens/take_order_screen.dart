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
import 'package:mostro_mobile/generated/l10n.dart';

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
      appBar: OrderAppBar(title: S.of(context)!.orderDetails),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildSellerAmount(ref, order!, context),
            const SizedBox(height: 16),
            _buildOrderId(context),
            const SizedBox(height: 24),
            _buildCountDownTime(order.expirationDate, context),
            const SizedBox(height: 36),
            // Pass the full order to the action buttons widget.
            _buildActionButtons(context, ref, order),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerAmount(WidgetRef ref, NostrEvent order, BuildContext context) {
    final selling = orderType == OrderType.sell ? S.of(context)!.selling : S.of(context)!.buying;
    final amountString =
        '${order.fiatAmount} ${order.currency} ${CurrencyUtils.getFlagFromCurrency(order.currency!)}';
    final satAmount = order.amount == '0' ? '' : ' ${order.amount}';
    final price = order.amount != '0' ? '' : S.of(context)!.atMarketPrice;
    final premium = int.parse(order.premium ?? '0');
    final premiumText = premium >= 0
        ? premium == 0
            ? ''
            : S.of(context)!.withPremiumPercent(premium.toString())
        : S.of(context)!.withDiscountPercent(premium.abs().toString());
    final methods = order.paymentMethods.isNotEmpty
        ? order.paymentMethods.join(', ')
        : S.of(context)!.noPaymentMethod;

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
                  S.of(context)!.someoneIsSellingBuying(selling, satAmount, amountString, price, premiumText),
                  style: AppTheme.theme.textTheme.bodyLarge,
                  softWrap: true,
                ),
                const SizedBox(height: 16),
                Text(
                  S.of(context)!.createdOnDate(formatDateTime(order.createdAt!)),
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  S.of(context)!.paymentMethodsAre(methods),
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
                SnackBar(
                  content: Text(S.of(context)!.orderIdCopied),
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

  Widget _buildCountDownTime(DateTime expiration, BuildContext context) {
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
        Text(S.of(context)!.timeLeft(countdown.toString().split('.')[0])),
      ],
    );
  }

  Widget _buildActionButtons(
      BuildContext context, WidgetRef ref, NostrEvent order) {
    final orderDetailsNotifier = ref.watch(
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
          child: Text(S.of(context)!.close),
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
                        title: Text(S.of(context)!.enterAmount),
                        content: TextField(
                          controller: _fiatAmountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText:
                                S.of(context)!.enterAmountBetween(order.fiatAmount.minimum.toString(), order.fiatAmount.maximum.toString()),
                            errorText: errorText,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(null),
                            child: Text(S.of(context)!.cancel),
                          ),
                          ElevatedButton(
                            key: const Key('submitAmountButton'),
                            onPressed: () {
                              final inputAmount = int.tryParse(
                                  _fiatAmountController.text.trim());
                              if (inputAmount == null) {
                                setState(() {
                                  errorText = S.of(context)!.pleaseEnterValidNumber;
                                });
                              } else if (inputAmount <
                                      order.fiatAmount.minimum ||
                                  inputAmount > order.fiatAmount.maximum!) {
                                setState(() {
                                  errorText =
                                      S.of(context)!.amountMustBeBetween(order.fiatAmount.minimum.toString(), order.fiatAmount.maximum.toString());
                                });
                              } else {
                                Navigator.of(context).pop(inputAmount);
                              }
                            },
                            child: Text(S.of(context)!.submit),
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
          child: Text(S.of(context)!.take),
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
