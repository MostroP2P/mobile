import 'package:flutter/material.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';

class OrderTypeHeader extends StatelessWidget {
  final OrderType orderType;

  const OrderTypeHeader({super.key, required this.orderType});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 0),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2230),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Text(
          orderType == OrderType.buy
              ? 'You want to buy Bitcoin'
              : 'You want to sell Bitcoin',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
