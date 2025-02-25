import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/shared/widgets/order_filter.dart';
import 'package:mostro_mobile/features/trades/providers/trades_provider.dart';
import 'package:mostro_mobile/features/trades/widgets/trades_list.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_bar.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_drawer.dart';

class TradesScreen extends ConsumerWidget {
  const TradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(filteredTradesProvider);

    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: const MostroAppBar(),
      drawer: const MostroAppDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: AppTheme.dark2,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'My Trades',
                  style: AppTheme.theme.textTheme.displayLarge,
                ),
              ),
              _buildFilterButton(context, state),
              const SizedBox(height: 6.0),
              Expanded(
                child: _buildOrderList(state),
              ),
              const BottomNavBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(BuildContext context, List<NostrEvent> trades) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (BuildContext context) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: OrderFilter(),
                  );
                },
              );
            },
            icon: const HeroIcon(HeroIcons.funnel,
                style: HeroIconStyle.outline, color: AppTheme.cream1),
            label:
                const Text("FILTER", style: TextStyle(color: AppTheme.cream1)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.cream1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "${trades.length} trades",
            style: const TextStyle(color: AppTheme.cream1),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<NostrEvent> trades) {
    if (trades.isEmpty) {
      return const Center(
        child: Text(
          'No trades available for this type',
          style: TextStyle(color: AppTheme.cream1),
        ),
      );
    }

    return TradesList(trades: trades);
  }
}
