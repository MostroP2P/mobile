import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/features/home/providers/home_order_providers.dart';
import 'package:mostro_mobile/features/home/widgets/order_list_item.dart';
import 'package:mostro_mobile/shared/widgets/add_order_button.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_bar.dart';
import 'package:mostro_mobile/shared/widgets/custom_drawer_overlay.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredOrders = ref.watch(filteredOrdersProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: const MostroAppBar(),
      body: CustomDrawerOverlay(
        child: Stack(
          children: [
            // Main content column with bottom navigation
            Column(
              children: [
                // Content area that expands to fill available space
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      return await ref.refresh(filteredOrdersProvider);
                    },
                    child: GestureDetector(
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity != null &&
                            details.primaryVelocity! < 0) {
                          ref.read(homeOrderTypeProvider.notifier).state =
                              OrderType.buy;
                        } else if (details.primaryVelocity != null &&
                            details.primaryVelocity! > 0) {
                          ref.read(homeOrderTypeProvider.notifier).state =
                              OrderType.sell;
                        }
                      },
                      child: Column(
                        children: [
                          _buildTabs(context, ref),
                          _buildFilterButton(context, ref),
                          Expanded(
                            child: Container(
                              color: const Color(0xFF1D212C),
                              child: filteredOrders.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.search_off,
                                            color: Colors.white30,
                                            size: 48,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            S.of(context)!.noOrdersAvailable,
                                            style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            S.of(context)!.tryChangingFilters,
                                            style: const TextStyle(
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
                                      padding: const EdgeInsets.only(
                                          bottom: 100, top: 6),
                                      itemBuilder: (context, index) {
                                        final order = filteredOrders[index];
                                        return OrderListItem(order: order);
                                      },
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Bottom navigation bar fixed at the bottom
                const BottomNavBar(),
              ],
            ),
            // Floating action button positioned above bottom nav bar
            Positioned(
              bottom: 80 + MediaQuery.of(context).viewPadding.bottom + 16,
              right: 16,
              child: const AddOrderButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs(BuildContext context, WidgetRef ref) {
    final orderType = ref.watch(homeOrderTypeProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildTabButton(
            context,
            ref,
            S.of(context)!.buyBtc,
            orderType == OrderType.sell,
            OrderType.sell,
            AppTheme.buyColor,
          ),
          _buildTabButton(
            context,
            ref,
            S.of(context)!.sellBtc,
            orderType == OrderType.buy,
            OrderType.buy,
            AppTheme.sellColor,
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    BuildContext context,
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
              color: isActive ? activeColor : AppTheme.textInactive,
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
      color: const Color(0xFF1D212C),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.backgroundInput,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
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
              Text(
                S.of(context)!.filter,
                style: const TextStyle(
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
                color: Colors.white.withValues(alpha: 0.2),
              ),
              Text(
                S.of(context)!.offersCount(filteredOrders.length.toString()),
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
    );
  }
}
