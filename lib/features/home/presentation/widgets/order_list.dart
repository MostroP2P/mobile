import 'package:flutter/material.dart';
import '../../../../data/models/order_model.dart';
import 'order_list_item.dart';

class OrderList extends StatelessWidget {
  final List<OrderModel> orders;

  const OrderList({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF303544),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: ListView.builder(
        itemCount: orders.length,
        itemBuilder: (context, index) {
          return OrderListItem(order: orders[index]);
        },
      ),
    );
  }
}
