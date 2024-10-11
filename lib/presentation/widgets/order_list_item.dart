import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/presentation/order/screens/order_details_screen.dart';
import '../../data/models/order_model.dart';

class OrderListItem extends StatelessWidget {
  final OrderModel order;

  const OrderListItem({Key? key, required this.order}) : super(key: key);

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
                    '${order.user} ${order.rating} (${order.ratingCount})',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Text(order.timeAgo,
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 8),
              Text('offering ${order.amount} ${order.currency}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              Text(
                  'for ${order.fiatAmount} ${order.fiatCurrency} ${order.premium}',
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              Row(
                children: [
                  HeroIcon(_getPaymentMethodIcon(order.paymentMethod),
                      style: HeroIconStyle.outline,
                      color: Colors.grey,
                      size: 16),
                  const SizedBox(width: 4),
                  Text(order.paymentMethod,
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
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
}
