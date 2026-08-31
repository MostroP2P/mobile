import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/core/automation/automation_id.dart';
import 'package:mostro_mobile/core/automation/automation_ids.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/features/home/providers/home_order_providers.dart';
import 'package:mostro_mobile/features/home/widgets/order_list_item.dart';
import 'package:mostro_mobile/shared/widgets/add_order_button.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_bar.dart';
import 'package:mostro_mobile/shared/widgets/order_filter.dart';
import 'package:mostro_mobile/shared/widgets/custom_drawer_overlay.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                          const Expanded(child: _OrderBookList()),
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
            AutomationIds.orderBookTabBuy,
          ),
          _buildTabButton(
            context,
            ref,
            S.of(context)!.sellBtc,
            orderType == OrderType.buy,
            OrderType.buy,
            AppTheme.sellColor,
            AutomationIds.orderBookTabSell,
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
    // Named by the visible tab, not by `type`: the Buy BTC tab filters for
    // sell orders, so deriving the id from `type` would swap the two.
    String automationId,
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
      ).withAutomationId(automationId),
    );
  }

  Widget _buildFilterButton(BuildContext context, WidgetRef ref) {
    // Only the count is rendered; watching the list rebuilt the pill (and
    // its shadowed containers) on every book emission.
    final offersCount =
        ref.watch(filteredOrdersProvider.select((orders) => orders.length));
    final activeFilterCount = ref.watch(activeFilterCountProvider);
    final hasFilters = activeFilterCount > 0;

    // When filters are active the pill is highlighted so the user can tell at a
    // glance that the offers list is being narrowed down.
    final foregroundColor =
        hasFilters ? AppTheme.mostroGreen : Colors.white70;
    final dividerColor = hasFilters
        ? AppTheme.mostroGreen.withValues(alpha: 0.4)
        : Colors.white.withValues(alpha: 0.2);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      color: AppTheme.dark1,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            color: hasFilters
                ? AppTheme.mostroGreen.withValues(alpha: 0.12)
                : AppTheme.backgroundInput,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: hasFilters
                  ? AppTheme.mostroGreen.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    showDialog<void>(
                      context: context,
                      builder: (BuildContext context) {
                        return const Dialog(
                          child: OrderFilter(),
                        );
                      },
                    );
                  },
                  borderRadius: BorderRadius.circular(30),
                  splashColor: AppTheme.activeColor.withValues(alpha: 0.3),
                  highlightColor: AppTheme.activeColor.withValues(alpha: 0.15),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: hasFilters ? 8 : 16,
                      top: 12,
                      bottom: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HeroIcon(
                          HeroIcons.funnel,
                          style: hasFilters
                              ? HeroIconStyle.solid
                              : HeroIconStyle.outline,
                          color: foregroundColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          hasFilters
                              ? S
                                  .of(context)!
                                  .filterWithCount(activeFilterCount.toString())
                              : S.of(context)!.filter,
                          style: TextStyle(
                            color: foregroundColor,
                            fontSize: 13,
                            fontWeight:
                                hasFilters ? FontWeight.w600 : FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          height: 16,
                          width: 1,
                          color: dividerColor,
                        ),
                        Text(
                          S
                              .of(context)!
                              .offersCount(offersCount.toString()),
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
                if (hasFilters)
                  _buildClearFiltersButton(context, ref, dividerColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Quick "clear all filters" action shown inside the filter pill.
  ///
  /// It sits outside the pill's main [InkWell] so tapping it resets the filters
  /// without also opening the filter dialog.
  Widget _buildClearFiltersButton(
    BuildContext context,
    WidgetRef ref,
    Color dividerColor,
  ) {
    final label = S.of(context)!.clearFilters;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 16,
          width: 1,
          color: dividerColor,
        ),
        Semantics(
          button: true,
          label: label,
          child: Tooltip(
            message: label,
            child: InkWell(
              onTap: () => clearAllOrderFilters(ref.read),
              borderRadius: BorderRadius.circular(30),
              splashColor: AppTheme.mostroGreen.withValues(alpha: 0.3),
              highlightColor: AppTheme.mostroGreen.withValues(alpha: 0.15),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: HeroIcon(
                    HeroIcons.xMark,
                    style: HeroIconStyle.outline,
                    color: AppTheme.mostroGreen,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The only widget that watches the full filtered list. Scoping the watch
/// here means a book emission rebuilds just the list — the tabs and the
/// filter pill above it watch narrower slices (order type, filter state,
/// order count) and stay put.
class _OrderBookList extends ConsumerWidget {
  const _OrderBookList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredOrders = ref.watch(filteredOrdersProvider);

    return Container(
      color: AppTheme.dark1,
      child: filteredOrders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
              padding: const EdgeInsets.only(bottom: 100, top: 6),
              itemBuilder: (context, index) {
                final order = filteredOrders[index];
                return OrderListItem(order: order);
              },
            ),
    );
  }
}
