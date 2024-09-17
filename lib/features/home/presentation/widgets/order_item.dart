import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/order_model.dart';

class OrderItem extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const OrderItem({
    super.key,
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.dark2,
      child: ListTile(
        title: Text(
            '${order.type.toUpperCase()} ${order.amount} ${order.currency}'),
        subtitle: Text('Status: ${order.status}'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}
