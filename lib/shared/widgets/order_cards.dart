import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/core/automation/automation_id.dart';
import 'package:mostro_mobile/core/automation/automation_ids.dart';
import 'package:mostro_mobile/data/models/user_info.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';

import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';
import 'package:mostro_mobile/shared/utils/currency_utils.dart';

import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/utils/snack_bar_helper.dart';

/// Card that displays the order amount information (selling/buying sats for amount)
class OrderAmountCard extends ConsumerWidget {
  final String title;
  final String amount;
  final String currency;
  final String? priceText;
  final String? premiumText;

  const OrderAmountCard({
    super.key,
    required this.title,
    required this.amount,
    required this.currency,
    this.priceText,
    this.premiumText,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyData = ref.watch(currencyCodesProvider).asData?.value;
    final currencyFlag =
        CurrencyUtils.getFlagFromCurrencyData(currency, currencyData);
    final amountString = '$amount $currencyFlag';

    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
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
                    text: S
                        .of(context)!
                        .forAmountWithCurrency(amountString, currency),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    children: [
                      if (priceText != null && priceText!.isNotEmpty)
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
          if (premiumText != null && premiumText!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              premiumText!,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Card that displays the payment method
class PaymentMethodCard extends StatelessWidget {
  final String paymentMethod;

  const PaymentMethodCard({super.key, required this.paymentMethod});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(
            Icons.payment,
            color: Colors.white70,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.paymentMethodLabel,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  paymentMethod,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card that displays the created date
class CreatedDateCard extends StatelessWidget {
  final String createdDate;

  const CreatedDateCard({super.key, required this.createdDate});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today,
            color: Colors.white70,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.createdOnLabel,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  createdDate,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card that displays the order ID with a copy button
class OrderIdCard extends StatelessWidget {
  final String orderId;

  const OrderIdCard({
    super.key,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.orderIdLabel,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  orderId,
                  style: const TextStyle(
                    color: AppTheme.mostroGreen,
                    fontSize: 14,
                  ),
                ).withAutomationId(AutomationIds.orderId),
              ),
              IconButton(
                icon: const Icon(
                  Icons.copy,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: orderId));
                  SnackBarHelper.showTopSnackBar(
                    context,
                    S.of(context)!.orderIdCopiedMessage,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card that displays the creator's reputation
class CreatorReputationCard extends StatelessWidget {
  final double rating;
  final int reviews;
  final int days;

  const CreatorReputationCard({
    super.key,
    required this.rating,
    required this.reviews,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.of(context)!.creatorReputationLabel,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            _ReputationMetricsRow(
              rating: rating,
              reviews: reviews,
              days: days,
            ),
          ],
        ),
      ),
    );
  }
}

/// Card that displays the counterpart's reputation, from the daemon's
/// taker-reputation notice. Keeps the same shape when there is no history
/// (new user or full-privacy taker), showing zeros in every metric.
class PeerReputationCard extends StatelessWidget {
  final UserInfo reputation;
  final bool counterpartIsBuyer;

  const PeerReputationCard({
    super.key,
    required this.reputation,
    required this.counterpartIsBuyer,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              counterpartIsBuyer
                  ? S.of(context)!.buyerReputationLabel
                  : S.of(context)!.sellerReputationLabel,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            _ReputationMetricsRow(
              rating: reputation.rating,
              reviews: reputation.reviews,
              days: reputation.operatingDays,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact, cardless counterpart reputation for dense layouts (invoice
/// screens): a title line plus "★ 4.4 / 5 · 4 reviews · 64 days". A
/// counterpart with no history reads as zeros, same as [PeerReputationCard].
class PeerReputationInline extends StatelessWidget {
  final UserInfo reputation;
  final bool counterpartIsBuyer;

  const PeerReputationInline({
    super.key,
    required this.reputation,
    required this.counterpartIsBuyer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          counterpartIsBuyer
              ? S.of(context)!.buyerReputationLabel
              : S.of(context)!.sellerReputationLabel,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star,
              color: AppTheme.mostroGreen,
              size: 18,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${reputation.rating.toStringAsFixed(1)} / 5 · '
                '${S.of(context)!.reputationReviewsCount(reputation.reviews)} · '
                '${S.of(context)!.reputationDaysCount(reputation.operatingDays)}',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Shared rating / reviews / days row used by the reputation cards
class _ReputationMetricsRow extends StatelessWidget {
  final double rating;
  final int reviews;
  final int days;

  const _ReputationMetricsRow({
    required this.rating,
    required this.reviews,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
                    rating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                S.of(context)!.ratingTitleLabel,
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
                  const Icon(
                    Icons.person_outline,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    reviews.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                S.of(context)!.reviewsLabel,
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
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    days.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                S.of(context)!.daysLabel,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Card that displays a notification message with an icon
class NotificationMessageCard extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color iconColor;

  const NotificationMessageCard({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.iconColor = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
