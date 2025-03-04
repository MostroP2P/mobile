import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/features/home/providers/home_order_providers.dart';
import 'package:mostro_mobile/features/home/widgets/order_list_item.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_bar.dart';
import 'package:mostro_mobile/shared/widgets/order_filter.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_drawer.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the filtered orders directly.
    final filteredOrders = ref.watch(filteredOrdersProvider);

    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: const MostroAppBar(),
      drawer: const MostroAppDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          return ref.refresh(filteredOrdersProvider);
        },
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.dark2,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _buildTabs(ref),
              const SizedBox(height: 12.0),
              _buildFilterButton(context, ref),
              const SizedBox(height: 6.0),
              Expanded(
                child: filteredOrders.isEmpty
                    ? const Center(
                        child: Text(
                          'No orders available for this type',
                          style: TextStyle(color: AppTheme.cream1),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredOrders.length,
                        itemBuilder: (context, index) {
                          final order = filteredOrders[index];
                          return OrderListItem(
                              order: order); // Your custom widget
                        },
                      ),
              ),
              const BottomNavBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs(WidgetRef ref) {
    final orderType = ref.watch(homeOrderTypeProvider);
    return Container(
      decoration: const BoxDecoration(
          color: AppTheme.dark1,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          )),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => ref.read(homeOrderTypeProvider.notifier).state =
                  OrderType.sell,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: orderType == OrderType.sell
                      ? AppTheme.dark2
                      : AppTheme.dark1,
                  borderRadius: BorderRadius.only(
                    topLeft:
                        Radius.circular((orderType == OrderType.sell) ? 20 : 0),
                    topRight:
                        Radius.circular(orderType == OrderType.sell ? 20 : 0),
                  ),
                ),
                child: Text(
                  "BUY BTC",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: orderType == OrderType.sell
                        ? AppTheme.mostroGreen
                        : AppTheme.red1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => ref.read(homeOrderTypeProvider.notifier).state =
                  OrderType.buy,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: orderType == OrderType.buy
                      ? AppTheme.dark2
                      : AppTheme.dark1,
                  borderRadius: BorderRadius.only(
                    topLeft:
                        Radius.circular((orderType == OrderType.buy) ? 20 : 0),
                    topRight:
                        Radius.circular(orderType == OrderType.buy ? 20 : 0),
                  ),
                ),
                child: Text(
                  "SELL BTC",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: orderType == OrderType.buy
                        ? AppTheme.mostroGreen
                        : AppTheme.red1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(BuildContext context, WidgetRef ref) {
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
            icon: const HeroIcon(
              HeroIcons.funnel,
              style: HeroIconStyle.outline,
              color: AppTheme.cream1,
            ),
            label: const Text(
              "FILTER",
              style: TextStyle(color: AppTheme.cream1),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.cream1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "${ref.watch(filteredOrdersProvider).length} offers",
            style: const TextStyle(color: AppTheme.cream1),
          ),
        ],
      ),
    );
  }
}
