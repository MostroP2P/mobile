import 'package:flutter/material.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/trades/widgets/trades_list_item.dart';

class TradesList extends StatelessWidget {
  final List<Order> orders;

  const TradesList({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return TradesListItem(order: orders[index]);
      },
    );
  }
}
