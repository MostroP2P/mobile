import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/theme/app_theme.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/presentation/order/screens/order_details_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class OrderListItem extends StatelessWidget {
  final NostrEvent order;

  const OrderListItem({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => OrderDetailsScreen(initialOrder: order),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1D212C),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.name} ${order.rating?.totalRating}/${order.rating?.maxRate} (${order.rating?.totalReviews})',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Text(
                    'Time: ${order.expiration}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              _buildStyledTextSpan(
                                'offering ',
                                '${order.amount}',
                                isValue: true,
                                isBold: true,
                              ),
                              const TextSpan(
                                text: "sats",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.normal,
                                  fontSize: 16.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text.rich(
                          TextSpan(
                            children: [
                              _buildStyledTextSpan(
                                'for ',
                                '${order.fiatAmount}',
                                isValue: true,
                                isBold: true,
                              ),
                              TextSpan(
                                text: '${order.currency} ',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.0,
                                ),
                              ),
                              TextSpan(
                                text: '(${order.premium}%)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        HeroIcon(
                          _getPaymentMethodIcon(order.paymentMethods.isNotEmpty 
                              ? order.paymentMethods[0] 
                              : ''),
                          style: HeroIconStyle.outline,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            order.paymentMethods.isNotEmpty 
                                ? order.paymentMethods[0] 
                                : 'No payment method',
                            style: const TextStyle(color: Colors.grey),
                            overflow: TextOverflow.visible,
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8), // Optional spacer after the row
            ],
          ),
        ),
      ),
    );
  }

  HeroIcons _getPaymentMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'wire transfer':
        return HeroIcons.buildingLibrary;
      case 'transferencia bancaria':
        return HeroIcons.buildingLibrary;
      case 'revolut':
        return HeroIcons.creditCard;
      default:
        return HeroIcons.banknotes;
    }
  }

  TextSpan _buildStyledTextSpan(String label, String value,
      {bool isValue = false, bool isBold = false}) {
    return TextSpan(
      text: label,
      style: TextStyle(
        color: AppTheme.cream1,
        fontWeight: FontWeight.normal,
        fontSize: isValue ? 16.0 : 24.0,
        fontFamily: GoogleFonts.robotoCondensed().fontFamily,
      ),
      children: isValue
          ? [
              TextSpan(
                text: '$value ',
                style: const TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ]
          : [],
    );
  }
}
