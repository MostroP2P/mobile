import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/app/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/features/home/notifiers/home_notifier.dart';
import 'package:mostro_mobile/features/home/providers/home_notifer_provider.dart';
import 'package:mostro_mobile/features/home/notifiers/home_state.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/shared/widgets/custom_app_bar.dart';
import 'package:mostro_mobile/features/home/widgets/order_filter.dart';
import 'package:mostro_mobile/features/home/widgets/order_list.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeStateAsync = ref.watch(homeNotifierProvider);
    final homeNotifier = ref.read(homeNotifierProvider.notifier);

    return homeStateAsync.when(
      data: (homeState) {
        return Scaffold(
          backgroundColor: AppTheme.dark1,
          appBar: const CustomAppBar(),
          drawer: Drawer(
            // Add a ListView to the drawer. This ensures the user can scroll
            // through the options in the drawer if there isn't enough vertical
            // space to fit everything.
            child: ListView(
              // Important: Remove any padding from the ListView.
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  title: const Text('Item 1'),
                  onTap: () {
                    // Update the state of the app.
                    // ...
                  },
                ),
                ListTile(
                  title: const Text('Item 2'),
                  onTap: () {
                    // Update the state of the app.
                    // ...
                  },
                ),
              ],
            ),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              await homeNotifier.refresh();
            },
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: AppTheme.dark2,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _buildTabs(ref, homeState, homeNotifier),
                  _buildFilterButton(context, homeState),
                  const SizedBox(height: 6.0),
                  Expanded(
                    child: _buildOrderList(homeState),
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

  Widget _buildTabs(
      WidgetRef ref, HomeState homeState, HomeNotifier homeNotifier) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.dark1,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child:
                _buildTab("BUY BTC", homeState.orderType == OrderType.sell, () {
              homeNotifier.changeOrderType(OrderType.sell);
            }),
          ),
          Expanded(
            child:
                _buildTab("SELL BTC", homeState.orderType == OrderType.buy, () {
              homeNotifier.changeOrderType(OrderType.buy);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String text, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.dark2 : AppTheme.dark1,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isActive ? 20 : 0),
            topRight: Radius.circular(isActive ? 20 : 0),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? AppTheme.mostroGreen : AppTheme.red1,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(BuildContext context, HomeState homeState) {
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
            "${homeState.filteredOrders.length} offers",
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(HomeState homeState) {
    if (homeState.filteredOrders.isEmpty) {
      return const Center(
        child: Text(
          'No orders available for this type',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return OrderList(orders: homeState.filteredOrders);
  }
}
