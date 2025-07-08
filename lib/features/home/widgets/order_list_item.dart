import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/shared/providers/time_provider.dart';
import 'package:mostro_mobile/shared/utils/currency_utils.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class OrderListItem extends ConsumerWidget {
  final NostrEvent order;

  const OrderListItem({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(timeProvider);

    // Determine if this is a fixed order (has specific sats amount and is not zero)
    final bool isFixedOrder =
        order.amount != null && order.amount != "0" && order.amount!.isNotEmpty;

    final premiumValue =
        order.premium != null ? double.tryParse(order.premium!) ?? 0.0 : 0.0;
    final isPremiumPositive = premiumValue >= 0;
    final premiumColor =
        isPremiumPositive ? AppTheme.buyColor : AppTheme.sellColor;
    final premiumText = premiumValue == 0
        ? "(0%)"
        : isPremiumPositive
            ? "(+$premiumValue%)"
            : "($premiumValue%)";

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            order.orderType == OrderType.buy
                ? context.push('/take_buy/${order.orderId}')
                : context.push('/take_sell/${order.orderId}');
          },
          highlightColor: Colors.white.withValues(alpha: 0.05),
          splashColor: Colors.white.withValues(alpha: 0.03),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // First row: "SELLING" label and timestamp
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // SELLING/BUYING label with more contrast
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundCard,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                            spreadRadius: -1,
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.08),
                            blurRadius: 1,
                            offset: const Offset(0, -1),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Text(
                        order.orderType == OrderType.buy
                            ? S.of(context)!.buying
                            : S.of(context)!.selling,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // Timestamp
                    Text(
                      order.timeAgoWithLocale(
                              Localizations.localeOf(context).languageCode) ??
                          S.of(context)!.hoursAgo('9'),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Second row: Amount and currency with flag and percentage (if not fixed)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        // Large amount with more contrast
                        Text(
                          order.fiatAmount.toString(),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Currency code and flag
                        Text(
                          '${order.currency ?? "CUP"} ',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          () {
                            final String currencyCode = order.currency ?? 'CUP';
                            return CurrencyUtils.getFlagFromCurrency(
                                    currencyCode) ??
                                '';
                          }(),
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),

                    // Display sats amount for all orders (simplified)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: isFixedOrder
                          ? Text(
                              S.of(context)!.forSats(order.amount!),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          : Row(
                              children: [
                                Text(
                                  '${S.of(context)!.marketPrice} ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  premiumText,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: premiumColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),

              // Third row: Payment method
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundCard,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                      spreadRadius: -2,
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.08),
                      blurRadius: 1,
                      offset: const Offset(0, -1),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Emoji for payment method
                    const Text(
                      '💳 ', // Default emoji
                      style: TextStyle(fontSize: 16),
                    ),
                    Expanded(
                      child: Text(
                        order.paymentMethods.isNotEmpty
                            ? order.paymentMethods.join(', ')
                            : 'tm',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Fourth row: Rating with stars
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundCard,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                      spreadRadius: -2,
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.08),
                      blurRadius: 1,
                      offset: const Offset(0, -1),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: _buildRatingRow(context, order),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingRow(BuildContext context, NostrEvent order) {
    final rating = order.rating?.totalRating ?? 0.0;

    final int reviews = order.rating?.totalReviews ?? 0;

    final int daysOld = order.rating?.days ?? 0;

    const Color starColor = Colors.amber;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              height: 20,
              child: ListView.builder(
                  shrinkWrap: true,
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  itemBuilder: (context, index) {

                    if (index < rating.floor()) {
                      return const Icon(Icons.star, color: starColor, size: 14);
                    } else if (index == rating.floor() &&
                        rating - rating.floor() >= 0.5) {
                      return const Icon(Icons.star_half,
                          color: starColor, size: 14);
                    } else {
                      return Icon(Icons.star_border,
                          color: starColor, size: 14);
                    }
                  }),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Semantics(
              label: '${S.of(context)!.reviews}: $reviews',
              child: Row(
                spacing: 4,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.person_2_outlined,
                      color: starColor,
                      size: 14,
                    ),
                  ),
                  Text(
                    reviews.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Semantics(
              label:
                  '${S.of(context)!.daysOld}: $daysOld ${S.of(context)!.daysOld}',
              child: Row(
                spacing: 4,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.calendar_today_outlined,
                      color: starColor,
                      size: 14,
                    ),
                  ),
                  Text(
                    daysOld.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
