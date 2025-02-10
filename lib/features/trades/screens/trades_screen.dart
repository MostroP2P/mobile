import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mostro_mobile/app/app_theme.dart';
import 'package:mostro_mobile/features/trades/notifiers/trades_state.dart';
import 'package:mostro_mobile/features/trades/providers/trades_notifier.dart';
import 'package:mostro_mobile/features/trades/widgets/trades_list.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_bar.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_drawer.dart';

class TradesScreen extends ConsumerWidget {
  const TradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderBookStateAsync = ref.watch(tradesNotifierProvider);

    return orderBookStateAsync.when(
      data: (orderBookState) {
        return Scaffold(
          backgroundColor: AppTheme.dark1,
          appBar: const MostroAppBar(),
          drawer: const MostroAppDrawer(),
          body: RefreshIndicator(
            onRefresh: () async {
              //await orderBookNotifier.refresh();
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
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'My Trades',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: GoogleFonts.robotoCondensed().fontFamily,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildOrderList(orderBookState),
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

  Widget _buildOrderList(TradesState orderBookState) {
    if (orderBookState.orders.isEmpty) {
      return const Center(
        child: Text(
          'No orders available for this type',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return TradesList(orders: orderBookState.orders);
  }
}
