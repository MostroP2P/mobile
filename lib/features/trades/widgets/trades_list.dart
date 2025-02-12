import 'package:flutter/material.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/trades/widgets/trades_list_item.dart';

class TradesList extends StatelessWidget {
  final List<Session> sessions;

  const TradesList({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        return TradesListItem(session: sessions[index]);
      },
    );
  }
}
