import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/features/home/providers/home_order_providers.dart';
import 'package:mostro_mobile/features/home/widgets/order_list_item.dart';
import 'package:mostro_mobile/shared/widgets/add_order_button.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/shared/widgets/order_filter.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_drawer.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredOrders = ref.watch(filteredOrdersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF171A23),
      appBar: _buildAppBar(),
      drawer: const MostroAppDrawer(),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              return await ref.refresh(filteredOrdersProvider);
            },
            child: Column(
              children: [
                _buildTabs(ref),
                _buildFilterButton(context, ref),
                Expanded(
                  child: Container(
                    color: const Color(0xFF171A23),
                    child: filteredOrders.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  color: Colors.white30,
                                  size: 48,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No orders available',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Try changing filter settings or check back later',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredOrders.length,
                            padding: const EdgeInsets.only(bottom: 80, top: 6),
                            itemBuilder: (context, index) {
                              final order = filteredOrders[index];
                              return OrderListItem(order: order);
                            },
                          ),
                  ),
                ),
                const BottomNavBar(),
              ],
            ),
          ),
          // Adding our button
          const AddOrderButton(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF171A23),
      elevation: 0,
      leadingWidth: 60,
      toolbarHeight: 56,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: Builder(
          builder: (context) => IconButton(
            icon: const HeroIcon(
              HeroIcons.bars3,
              style: HeroIconStyle.outline,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const HeroIcon(
                  HeroIcons.bell,
                  style: HeroIconStyle.outline,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () {
                  // Action for notifications
                },
              ),
              // Indicator for the number of notifications
              Positioned(
                top: 12,
                right: 8,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      '6',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabs(WidgetRef ref) {
    final orderType = ref.watch(homeOrderTypeProvider);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF171A23), // Exact dark background
        border: Border(
          bottom: BorderSide(
            color: Colors.white
                .withOpacity(0.1), // Same style as the other divider lines
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildTabButton(
            ref,
            "BUY BTC",
            orderType == OrderType.sell,
            OrderType.sell,
            const Color(0xFF8CC63F), // Exact green
          ),
          _buildTabButton(
            ref,
            "SELL BTC",
            orderType == OrderType.buy,
            OrderType.buy,
            const Color(0xFFEA384C), // Exact red
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    WidgetRef ref,
    String text,
    bool isActive,
    OrderType type,
    Color activeColor,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () => ref.read(homeOrderTypeProvider.notifier).state = type,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? activeColor : Colors.transparent,
                width: 3.0, // Thicker line
              ),
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive
                  ? activeColor
                  : const Color(0xFF8A8D98), // Specific gray when not active
              fontWeight: FontWeight.w600, // Semi-bold
              fontSize: 15,
              letterSpacing: 0.5, // Letter spacing
              fontFamily: 'Roboto', // Assuming Roboto as font
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(BuildContext context, WidgetRef ref) {
    final filteredOrders = ref.watch(filteredOrdersProvider);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      // Changing the color to match the background of the orders
      color: const Color(0xFF171A23),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () {
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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF252A3A),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
              // Adding subtle shadow
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const HeroIcon(
                  HeroIcons.funnel,
                  style: HeroIconStyle.outline,
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  "FILTER",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  height: 16,
                  width: 1,
                  color: Colors.white.withOpacity(0.2),
                ),
                Text(
                  "${filteredOrders.length} offers",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
