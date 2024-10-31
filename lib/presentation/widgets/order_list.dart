import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'order_list_item.dart';

class OrderList extends StatelessWidget {
  final List<NostrEvent> orders;

  const OrderList({super.key, required this.orders});

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
