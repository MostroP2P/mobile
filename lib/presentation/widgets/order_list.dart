import 'package:flutter/material.dart';
import '../../data/models/order_model.dart';
import 'order_list_item.dart';

class OrderList extends StatelessWidget {
  final List<OrderModel> orders;

  const OrderList({Key? key, required this.orders}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return OrderListItem(order: orders[index]);
      },
    );
  }
}
