import 'package:flutter/material.dart';
import '../../../../data/models/order_model.dart';
import 'order_item.dart';

class OrderList extends StatelessWidget {
  final List<OrderModel> orders;
  final Function(OrderModel) onOrderSelected;

  const OrderList({
    super.key,
    required this.orders,
    required this.onOrderSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return OrderItem(
          order: order,
          onTap: () => onOrderSelected(order),
        );
      },
    );
  }
}
