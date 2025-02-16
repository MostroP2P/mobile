import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/shared/widgets/order_filter.dart';
import 'package:mostro_mobile/features/trades/notifiers/trades_state.dart';
import 'package:mostro_mobile/features/trades/providers/trades_provider.dart';
import 'package:mostro_mobile/features/trades/widgets/trades_list.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_bar.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_drawer.dart';

class TradesScreen extends ConsumerWidget {
  const TradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradesAsync = ref.watch(tradesProvider);

    return tradesAsync.when(
      data: (state) {
        return Scaffold(
          backgroundColor: AppTheme.dark1,
          appBar: const MostroAppBar(),
          drawer: const MostroAppDrawer(),
          body: RefreshIndicator(
            onRefresh: () async {
              // Force a refresh of sessions
              //ref.refresh(tradesProvider);
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
      },
      loading: () => const Scaffold(
        backgroundColor: AppTheme.dark1,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: AppTheme.dark1,
        body: Center(
          child: Text(
            'Error: $error',
            style: const TextStyle(color: AppTheme.cream1),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(BuildContext context, TradesState homeState) {
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
                style: HeroIconStyle.outline, color: Colors.white),
            label: const Text("FILTER", style: TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "${homeState.orders.length} trades",
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }


  Widget _buildOrderList(TradesState state) {
    if (state.orders.isEmpty) {
      return const Center(
        child: Text(
          'No trades available for this type',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return TradesList(state: state);
  }
}
