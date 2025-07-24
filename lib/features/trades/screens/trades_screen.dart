import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/features/trades/providers/trades_provider.dart';
import 'package:mostro_mobile/features/trades/widgets/trades_list.dart';
import 'package:mostro_mobile/features/trades/widgets/status_filter_widget.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_bar.dart';
import 'package:mostro_mobile/shared/widgets/custom_drawer_overlay.dart';

class TradesScreen extends ConsumerWidget {
  const TradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the async trades data
    final tradesAsync = ref.watch(filteredTradesWithOrderStateProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: const MostroAppBar(),
      body: CustomDrawerOverlay(
        child: RefreshIndicator(
          onRefresh: () async {
            // Force reload the orders repository first
            ref.read(orderRepositoryProvider).reloadData();
            // Then refresh the filtered trades provider
            ref.invalidate(filteredTradesWithOrderStateProvider);
          },
          child: Column(
            children: [
              Expanded(
                child: Column(
                  children: [
                    // Header with dark background and status filter
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundDark,
                        border: Border(
                          bottom: BorderSide(color: Colors.white24, width: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            S.of(context)!.myTrades,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // Status Filter Dropdown
                          const StatusFilterWidget(),
                        ],
                      ),
                    ),
                    // Content area with dark background
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppTheme.backgroundDark,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 16.0),
                            Expanded(
                              child: tradesAsync.when(
                                data: (trades) =>
                                    _buildOrderList(context, trades),
                                loading: () => Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.cream1,
                                  ),
                                ),
                                error: (error, stackTrace) => Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: Colors.red,
                                        size: 48,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        S.of(context)!.errorLoadingTrades,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: () {
                                          ref.invalidate(orderEventsProvider);
                                          ref.invalidate(
                                              filteredTradesWithOrderStateProvider);
                                        },
                                        child: Text(S.of(context)!.retry),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const BottomNavBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderList(BuildContext context, List<NostrEvent> trades) {
    if (trades.isEmpty) {
      return Center(
        child: Text(
          S.of(context)!.noTradesAvailable,
          style: const TextStyle(color: AppTheme.cream1),
        ),
      );
    }

    return TradesList(trades: trades);
  }
}
