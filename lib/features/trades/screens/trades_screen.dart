import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/features/trades/providers/trades_provider.dart';
import 'package:mostro_mobile/features/trades/widgets/trades_list.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_bar.dart';
import 'package:mostro_mobile/shared/widgets/custom_drawer_overlay.dart';

class TradesScreen extends ConsumerWidget {
  const TradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the async trades data
    final tradesAsync = ref.watch(filteredTradesProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: const MostroAppBar(),
      body: CustomDrawerOverlay(
        child: RefreshIndicator(
          onRefresh: () async {
            // Force reload the orders repository first
            ref.read(orderRepositoryProvider).reloadData();
            // Then refresh the filtered trades provider
            ref.invalidate(filteredTradesProvider);
          },
          child: Column(
            children: [
              Expanded(
                child: Column(
                  children: [
                    // Header with dark background
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundDark,
                        border: Border(
                          bottom: BorderSide(color: Colors.white24, width: 0.5),
                        ),
                      ),
                      child: Text(
                        S.of(context)!.myActiveTrades,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Content area with dark background
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppTheme.backgroundDark,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 16.0),
                            Expanded(
                              child: tradesAsync.when(
                                data: (trades) =>
                                    _buildOrderList(context, trades),
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
                                        S.of(context)!.errorLoadingTrades,
                                        style:
                                            TextStyle(color: AppTheme.cream1),
                                      ),
                                      Text(
                                        error.toString(),
                                        style: TextStyle(
                                            color: AppTheme.cream1,
                                            fontSize: 12),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: () {
                                          ref.invalidate(orderEventsProvider);
                                          ref.invalidate(
                                              filteredTradesProvider);
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
