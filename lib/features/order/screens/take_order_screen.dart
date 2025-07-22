import 'package:circular_countdown/circular_countdown.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/shared/widgets/order_cards.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/shared/providers/time_provider.dart';
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
      backgroundColor: AppTheme.backgroundDark,
      appBar: OrderAppBar(
          title: orderType == OrderType.buy
              ? S.of(context)!.buyOrderDetailsTitle
              : S.of(context)!.sellOrderDetailsTitle),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildSellerAmount(ref, order!),
            const SizedBox(height: 16),
            _buildPaymentMethod(context, order),
            const SizedBox(height: 16),
            _buildCreatedOn(order),
            const SizedBox(height: 16),
            _buildOrderId(context),
            const SizedBox(height: 16),
            _buildCreatorReputation(order),
            const SizedBox(height: 24),
            _CountdownWidget(
              expirationDate: order.expirationDate,
            ),
            const SizedBox(height: 36),
            _buildActionButtons(context, ref, order),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerAmount(WidgetRef ref, NostrEvent order) {
    return Builder(
      builder: (context) {
        final priceText =
            order.amount == '0' ? S.of(context)!.atMarketPrice : '';

        final hasFixedSatsAmount = order.amount != null && order.amount != '0';

        return CustomCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasFixedSatsAmount
                    ? (orderType == OrderType.sell
                        ? "${S.of(context)!.someoneIsSellingTitle.replaceAll(' Sats', '')} ${order.amount} Sats"
                        : "${S.of(context)!.someoneIsBuyingTitle.replaceAll(' Sats', '')} ${order.amount} Sats")
                    : (orderType == OrderType.sell
                        ? S.of(context)!.someoneIsSellingTitle
                        : S.of(context)!.someoneIsBuyingTitle),
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
                    S.of(context)!.forAmount(order.fiatAmount.toString(), order.currency!),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  if (priceText.isNotEmpty) ...[
                    // Fixed [...] brackets
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
      },
    );
  }

  Widget _buildOrderId(BuildContext context) {
    return OrderIdCard(
      orderId: orderId,
    );
  }

  Widget _buildPaymentMethod(BuildContext context, NostrEvent order) {
    final methods = order.paymentMethods.isNotEmpty
        ? order.paymentMethods.join(', ')
        : S.of(context)!.noPaymentMethod;

    return PaymentMethodCard(
      paymentMethod: methods,
    );
  }

  Widget _buildCreatedOn(NostrEvent order) {
    return Builder(
      builder: (context) {
        return CreatedDateCard(
          createdDate: formatDateTime(order.createdAt!, context),
        );
      },
    );
  }

  Widget _buildCreatorReputation(NostrEvent order) {
    final ratingInfo = order.rating;

    final rating = ratingInfo?.totalRating ?? 0.0;
    final reviews = ratingInfo?.totalReviews ?? 0;
    final days = ratingInfo?.days ?? 0;

    return CreatorReputationCard(
      rating: rating,
      reviews: reviews,
      days: days,
    );
  }

  Widget _buildActionButtons(
      BuildContext context, WidgetRef ref, NostrEvent order) {
    final orderDetailsNotifier =
        ref.read(orderNotifierProvider(orderId).notifier);

    final buttonText =
        orderType == OrderType.buy ? S.of(context)!.sell : S.of(context)!.buy;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: AppTheme.theme.outlinedButtonTheme.style,
            child: Text(S.of(context)!.close),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              // Check if this is a range order
              if (order.fiatAmount.maximum != null &&
                  order.fiatAmount.minimum != order.fiatAmount.maximum) {
                // Show dialog to get the amount
                String? errorText;
                final enteredAmount = await showDialog<int>(
                  context: context,
                  builder: (context) {
                    return StatefulBuilder(
                      builder: (context, setState) {
                        return AlertDialog(
                          title: Text(S.of(context)!.enterAmount),
                          content: TextField(
                            controller: _fiatAmountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: S.of(context)!.enterAmountBetween(
                                  order.fiatAmount.minimum.toString(),
                                  order.fiatAmount.maximum.toString()),
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
                                    errorText =
                                        S.of(context)!.pleaseEnterValidNumber;
                                  });
                                } else if (inputAmount <
                                        order.fiatAmount.minimum ||
                                    (order.fiatAmount.maximum != null &&
                                        inputAmount >
                                            order.fiatAmount.maximum!)) {
                                  setState(() {
                                    errorText = S
                                        .of(context)!
                                        .amountMustBeBetween(
                                            order.fiatAmount.minimum.toString(),
                                            order.fiatAmount.maximum
                                                .toString());
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
            child: Text(buttonText),
          ),
        ),
      ],
    );
  }

  String formatDateTime(DateTime dt, [BuildContext? context]) {
    if (context != null) {
      // Use internationalized date format
      final dateFormatter =
          DateFormat.yMMMd(Localizations.localeOf(context).languageCode);
      final timeFormatter =
          DateFormat.Hm(Localizations.localeOf(context).languageCode);
      final formattedDate = dateFormatter.format(dt);
      final formattedTime = timeFormatter.format(dt);

      // Use the internationalized string for "Created on: date"
      return S.of(context)!.createdOnDate('$formattedDate $formattedTime');
    } else {
      // Fallback if context is not available
      final dateFormatter = DateFormat('EEE, MMM dd yyyy');
      final timeFormatter = DateFormat('HH:mm');
      final formattedDate = dateFormatter.format(dt);
      final formattedTime = timeFormatter.format(dt);

      return '$formattedDate at $formattedTime';
    }
  }
}

/// Widget that displays a real-time countdown timer for pending orders
class _CountdownWidget extends ConsumerWidget {
  final DateTime expirationDate;

  const _CountdownWidget({
    required this.expirationDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the countdown time provider for real-time updates
    final timeAsync = ref.watch(countdownTimeProvider);

    return timeAsync.when(
      data: (currentTime) {
        return _buildCountDownTime(context, ref, expirationDate);
      },
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildCountDownTime(
      BuildContext context, WidgetRef ref, DateTime expiration) {
    Duration countdown = Duration(hours: 0);
    final now = DateTime.now();

    // Handle edge case: expiration in the past
    if (expiration.isBefore(now.subtract(const Duration(hours: 1)))) {
      // If expiration is more than 1 hour in the past, likely invalid
      return const SizedBox.shrink();
    }

    if (expiration.isAfter(now)) {
      countdown = expiration.difference(now);
    }

    // Get dynamic expiration hours from Mostro instance
    final mostroInstance = ref.read(orderRepositoryProvider).mostroInstance;
    final maxOrderHours =
        mostroInstance?.expirationHours ?? 24; // fallback to 24 hours

    // Validate expiration hours
    if (maxOrderHours <= 0 || maxOrderHours > 168) { // Max 1 week
      return const SizedBox.shrink();
    }

    final hoursLeft = countdown.inHours.clamp(0, maxOrderHours);
    final minutesLeft = countdown.inMinutes % 60;
    final secondsLeft = countdown.inSeconds % 60;

    final formattedTime =
        '${hoursLeft.toString().padLeft(2, '0')}:${minutesLeft.toString().padLeft(2, '0')}:${secondsLeft.toString().padLeft(2, '0')}';

    return Column(
      children: [
        CircularCountdown(
          countdownTotal: maxOrderHours,
          countdownRemaining: hoursLeft,
        ),
        const SizedBox(height: 16),
        Text(S.of(context)!.timeLeftLabel(formattedTime)),
      ],
    );
  }
}
