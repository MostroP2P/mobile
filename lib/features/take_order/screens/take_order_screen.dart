import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/app/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/take_order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/features/take_order/widgets/buyer_info.dart';
import 'package:mostro_mobile/features/take_order/widgets/seller_info.dart';
import 'package:mostro_mobile/presentation/widgets/currency_text_field.dart';
import 'package:mostro_mobile/presentation/widgets/exchange_rate_widget.dart';
import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';
import 'package:mostro_mobile/features/take_order/providers/order_notifier_providers.dart';

class TakeOrderScreen extends ConsumerWidget {
  final String orderId;
  final OrderType orderType;
  final TextEditingController _satsAmountController = TextEditingController();
  final TextEditingController _lndAddressController = TextEditingController();

  TakeOrderScreen({super.key, required this.orderId, required this.orderType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1) Watch asynchronous order fetch
    final orderAsyncValue = ref.watch(eventProvider(orderId));

    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: OrderAppBar(
          title: '${orderType == OrderType.buy ? "SELL" : "BUY"} BITCOIN'),
      body: orderAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (order) {
          // If order is null => show "Order not found"
          if (order == null) {
            return const Center(child: Text('Order not found'));
          }

          // Build the main UI with the order
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                CustomCard(
                  padding: const EdgeInsets.all(16),
                  child: SellerInfo(order: order),
                ),
                const SizedBox(height: 16),
                _buildSellerAmount(ref, order),
                const SizedBox(height: 16),
                // Exchange rate widget
                if (order.currency != null)
                  ExchangeRateWidget(currency: order.currency!),
                const SizedBox(height: 16),
                CustomCard(
                  padding: const EdgeInsets.all(16),
                  child: BuyerInfo(order: order),
                ),
                const SizedBox(height: 16),
                _buildBuyerAmount(int.tryParse(order.amount!)),
                const SizedBox(height: 16),
                _buildLnAddress(),
                const SizedBox(height: 16),
                _buildActionButtons(context, ref, order.id),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSellerAmount(WidgetRef ref, NostrEvent order) {
    final exchangeRateAsyncValue =
        ref.watch(exchangeRateProvider(order.currency!));
    return exchangeRateAsyncValue.when(
      loading: () => const CircularProgressIndicator(),
      error: (error, _) => Text('Exchange rate error: $error'),
      data: (exchangeRate) {
        // Example usage: exchangeRate might be a double or something
        return CustomCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${order.fiatAmount} ${order.currency} (${order.premium}%)',
                    style: const TextStyle(
                      color: AppTheme.cream1,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${order.amount} sats',
                    style: const TextStyle(color: AppTheme.grey2),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildBuyerAmount(int? amount) {
    final safeAmount = amount ?? 0;
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CurrencyTextField(controller: _satsAmountController, label: 'Sats'),
          const SizedBox(height: 8),
          Text('\$ $safeAmount', style: const TextStyle(color: AppTheme.grey2)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLnAddress() {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: TextFormField(
        controller: _lndAddressController,
        style: const TextStyle(color: AppTheme.cream1),
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: "Enter a Lightning Address",
          labelStyle: const TextStyle(color: AppTheme.grey2),
          filled: true,
          fillColor: AppTheme.dark1,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter a value';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, WidgetRef ref, String? orderId) {
    // If there's no orderId, hide the button or handle it
    final realOrderId = orderId ?? '';

    final orderDetailsNotifier = orderType == OrderType.sell ?
    ref.read(takeSellOrderNotifierProvider(realOrderId).notifier):
    ref.read(takeBuyOrderNotifierProvider(realOrderId).notifier);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton(
          onPressed: () {
            context.go('/');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.red1,
          ),
          child: const Text('CANCEL'),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: () {
            // Possibly pass the LN address or sats from the text fields
            final satsText = _satsAmountController.text;
            // Convert satsText to int if needed
            final satsAmount = int.tryParse(satsText);
            if (orderType == OrderType.buy) {
              orderDetailsNotifier.takeBuyOrder(realOrderId, satsAmount);
            } else {
              final lndAddress = _lndAddressController.text.trim();
              orderDetailsNotifier.takeSellOrder(
                  realOrderId, satsAmount, lndAddress);
            } // Could also pass the LN address if your method expects it
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.mostroGreen,
          ),
          child: const Text('CONTINUE'),
        ),
      ],
    );
  }
}
