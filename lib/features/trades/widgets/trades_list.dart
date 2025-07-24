import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:mostro_mobile/features/trades/widgets/trades_list_item.dart';

class TradesList extends StatelessWidget {
  final List<NostrEvent> trades;

  const TradesList({super.key, required this.trades});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: trades.length,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewPadding.bottom + 16,
      ),
      itemBuilder: (context, index) {
        return TradesListItem(trade: trades[index]);
      },
    );
  }
}
