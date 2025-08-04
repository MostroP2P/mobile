import 'package:circular_countdown/circular_countdown.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/shared/widgets/order_cards.dart';


import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';
import 'package:mostro_mobile/shared/utils/currency_utils.dart';

import 'package:mostro_mobile/shared/widgets/custom_card.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/shared/providers/time_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class TakeOrderScreen extends ConsumerStatefulWidget {
  final String orderId;
  final OrderType orderType;
  final TextEditingController _fiatAmountController = TextEditingController();
  final TextEditingController _lndAddressController = TextEditingController();
  final TextTheme textTheme = AppTheme.theme.textTheme;

  TakeOrderScreen({super.key, required this.orderId, required this.orderType});

  @override
  ConsumerState<TakeOrderScreen> createState() => _TakeOrderScreenState();
}

class _TakeOrderScreenState extends ConsumerState<TakeOrderScreen> {
  bool _isSubmitting = false;
  dynamic _lastSeenAction;

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(eventProvider(widget.orderId));

    // Listen for messages to reset loading state on CantDo
    ref.listen(
      mostroMessageStreamProvider(widget.orderId),
      (_, next) {
        next.whenData((msg) {
          if (msg == null || msg.action == _lastSeenAction) return;
          _lastSeenAction = msg.action;
          
          // Reset loading state only on CantDo message
          if (msg.action == actions.Action.cantDo && _isSubmitting) {
            setState(() {
              _isSubmitting = false;
            });
          }
        });
      },
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: OrderAppBar(
          title: widget.orderType == OrderType.buy
              ? S.of(context)!.buyOrderDetailsTitle
              : S.of(context)!.sellOrderDetailsTitle),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16.0,
          16.0,
          16.0,
          16.0 + MediaQuery.of(context).viewPadding.bottom,
        ),
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

        final currencyData = ref.watch(currencyCodesProvider).asData?.value;
        final currencyFlag = CurrencyUtils.getFlagFromCurrencyData(
            order.currency!, currencyData);
        final amountString =
            '${order.fiatAmount} ${order.currency} $currencyFlag';
        String priceText = '';
        if (order.amount == '0') {
          final premium = order.premium;
          final premiumValue =
              premium != null ? double.tryParse(premium) ?? 0.0 : 0.0;

          if (premiumValue == 0) {
            // No premium - show only market price
            priceText = S.of(context)!.atMarketPrice;
          } else {
            // Has premium/discount - show market price with percentage
            final isPremiumPositive = premiumValue >= 0;
            final premiumDisplay =
                isPremiumPositive ? '(+$premiumValue%)' : '($premiumValue%)';
            priceText = '${S.of(context)!.atMarketPrice} $premiumDisplay';
          }
        }


        final hasFixedSatsAmount = order.amount != '0';


        return CustomCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasFixedSatsAmount
                    ? (widget.orderType == OrderType.sell
                        ? "${S.of(context)!.someoneIsSellingTitle.replaceAll(' Sats', '')} ${order.amount} Sats"
                        : "${S.of(context)!.someoneIsBuyingTitle.replaceAll(' Sats', '')} ${order.amount} Sats")
                    : (widget.orderType == OrderType.sell
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

                  Flexible(
                    child: RichText(
                      text: TextSpan(
                        text: S.of(context)!.forAmount(amountString, order.currency ?? ''),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                        children: [
                          if (priceText.isNotEmpty)
                            TextSpan(
                              text: ' $priceText',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 15,
                              ),
                            ),
                        ],

                      ),
                      softWrap: true,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
      orderId: widget.orderId,
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
        ref.read(orderNotifierProvider(widget.orderId).notifier);

    final buttonText =
        widget.orderType == OrderType.buy ? S.of(context)!.sell : S.of(context)!.buy;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => context.pop(),
            style: AppTheme.theme.outlinedButtonTheme.style,
            child: Text(S.of(context)!.close),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : () async {
              setState(() {
                _isSubmitting = true;
              });
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
                            controller: widget._fiatAmountController,
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
                              onPressed: () => context.pop(),
                              child: Text(S.of(context)!.cancel),
                            ),
                            ElevatedButton(
                              key: const Key('submitAmountButton'),
                              onPressed: () {
                                final inputAmount = int.tryParse(
                                  widget._fiatAmountController.text.trim());
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
                                  context.pop(inputAmount);
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
                  if (widget.orderType == OrderType.buy) {
                    await orderDetailsNotifier.takeBuyOrder(
                        order.orderId!, enteredAmount);
                  } else {
                    final lndAddress = widget._lndAddressController.text.trim();
                    await orderDetailsNotifier.takeSellOrder(
                      order.orderId!,
                      enteredAmount,
                      lndAddress.isEmpty ? null : lndAddress,
                    );
                  }
                } else {
                  // Dialog was dismissed without entering amount, reset loading state
                  setState(() {
                    _isSubmitting = false;
                  });
                }
              } else {
                // Not a range order – use the existing logic.
                final fiatAmount =
                    int.tryParse(widget._fiatAmountController.text.trim());
                if (widget.orderType == OrderType.buy) {
                  await orderDetailsNotifier.takeBuyOrder(
                      order.orderId!, fiatAmount);
                } else {
                  final lndAddress = widget._lndAddressController.text.trim();
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
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(buttonText),
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
    if (maxOrderHours <= 0 || maxOrderHours > 168) {
      // Max 1 week
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
