import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import '../../data/models/order_model.dart';

class OrderListItem extends StatelessWidget {
  final OrderModel order;

  const OrderListItem({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1D212C), // Color del fondo general
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
              color: const Color(0xFF303544),
              width: 1), // Borde del color del contenedor más claro
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${order.user} ${order.rating}/5 (${order.ratingCount})",
                  style: const TextStyle(color: Colors.white),
                ),
                Text(
                  order.timeAgo,
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "offering ${order.amount} ${order.currency}",
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              "for ${order.fiatAmount} ${order.fiatCurrency} (${order.premium})",
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                HeroIcon(
                  _getPaymentMethodIcon(order.paymentMethod),
                  style: HeroIconStyle.outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  order.paymentMethod,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ],
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
