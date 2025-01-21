import 'package:flutter/material.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/order_book/widgets/order_book_list_item.dart';

class OrderBookList extends StatelessWidget {
  final List<Order> orders;

  const OrderBookList({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return OrderBookListItem(order: orders[index]);
      },
    );
  }
}
