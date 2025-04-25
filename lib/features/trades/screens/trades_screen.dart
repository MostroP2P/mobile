import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
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
    // Watch the async trades data
    final tradesAsync = ref.watch(filteredTradesProvider);
    
    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: const MostroAppBar(),
      drawer: const MostroAppDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          // Force reload the orders repository first
          await ref.read(orderRepositoryProvider).reloadData();
          // Then refresh the filtered trades provider
          ref.invalidate(filteredTradesProvider);
        },
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
                  'MY TRADES',
                  style: TextStyle(color: AppTheme.mostroGreen),
                ),
              ),
              // Use the async value pattern to handle different states
              tradesAsync.when(
                data: (trades) => _buildFilterButton(context, trades),
                loading: () => _buildFilterButton(context, []),
                error: (error, _) => _buildFilterButton(context, []),
              ),
              const SizedBox(height: 6.0),
              Expanded(
                child: tradesAsync.when(
                  data: (trades) => _buildOrderList(trades),
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading trades',
                          style: TextStyle(color: AppTheme.cream1),
                        ),
                        Text(
                          error.toString(),
                          style: TextStyle(color: AppTheme.cream1, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            ref.invalidate(orderEventsProvider);
                            ref.invalidate(filteredTradesProvider);
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          // Add a manual refresh button
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.cream1),
            onPressed: () {
              // Get the riverpod context from the widget
              final container = ProviderScope.containerOf(context, listen: false);
              // Invalidate providers to force refresh
              container.invalidate(orderEventsProvider);
              container.invalidate(filteredTradesProvider);
            },
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
