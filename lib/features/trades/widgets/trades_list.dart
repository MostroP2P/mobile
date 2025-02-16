import 'package:flutter/material.dart';
import 'package:mostro_mobile/features/trades/notifiers/trades_state.dart';
import 'package:mostro_mobile/features/trades/widgets/trades_list_item.dart';

class TradesList extends StatelessWidget {
  final TradesState state;

  const TradesList({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: state.orders.length,
      itemBuilder: (context, index) {
        return TradesListItem(trade: state.orders[index]);
      },
    );
  }
}
