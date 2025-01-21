import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mostro_mobile/app/app_theme.dart';
import 'package:mostro_mobile/features/order_book/notifiers/order_book_state.dart';
import 'package:mostro_mobile/features/order_book/providers/order_book_notifier.dart';
import 'package:mostro_mobile/features/order_book/widgets/order_book_list.dart';
import 'package:mostro_mobile/presentation/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/presentation/widgets/custom_app_bar.dart';

class OrderBookScreen extends ConsumerWidget {
  const OrderBookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderBookStateAsync = ref.watch(orderBookNotifierProvider);

    return orderBookStateAsync.when(
      data: (orderBookState) {
        return Scaffold(
          backgroundColor: AppTheme.dark1,
          appBar: const CustomAppBar(),
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
                      'My Order Book',
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

  Widget _buildOrderList(OrderBookState orderBookState) {
    if (orderBookState.orders.isEmpty) {
      return const Center(
        child: Text(
          'No orders available for this type',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return OrderBookList(orders: orderBookState.orders);
  }
}
