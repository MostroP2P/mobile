import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/app/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/take_order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/features/take_order/widgets/seller_info.dart';
import 'package:mostro_mobile/shared/widgets/currency_text_field.dart';
import 'package:mostro_mobile/shared/widgets/exchange_rate_widget.dart';
import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';
import 'package:mostro_mobile/features/take_order/providers/order_notifier_providers.dart';

class TakeOrderScreen extends ConsumerWidget {
  final String orderId;
  final OrderType orderType;
  final TextEditingController _fiatAmountController = TextEditingController();
  final TextEditingController _lndAddressController = TextEditingController();

  TakeOrderScreen({super.key, required this.orderId, required this.orderType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsyncValue = ref.watch(eventProvider(orderId));

    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: OrderAppBar(
          title: '${orderType == OrderType.buy ? "SELL" : "BUY"} BITCOIN'),
      body: orderAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (order) {
          if (order == null) {
            return Center(child: Text('Order $orderId not found'));
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
                ExchangeRateWidget(currency: order.currency!),
                const SizedBox(height: 16),
                if ((orderType == OrderType.sell && order.amount != '0') ||
                    order.fiatAmount.maximum != null)
                  _buildBuyerAmount(int.tryParse(order.amount!)),
                _buildLnAddress(),
                const SizedBox(height: 16),
                _buildActionButtons(context, ref, order.orderId!),
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
    return Column(children: [
      CustomCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CurrencyTextField(controller: _fiatAmountController, label: 'Fiat'),
            const SizedBox(height: 8),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ]);
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
      BuildContext context, WidgetRef ref, String orderId) {

    final orderDetailsNotifier = (orderType == OrderType.sell)
        ? ref.read(takeSellOrderNotifierProvider(orderId).notifier)
        : ref.read(takeBuyOrderNotifierProvider(orderId).notifier);

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
          onPressed: () async {
            final fiatAmount = int.tryParse(_fiatAmountController.text.trim());

            if (orderType == OrderType.buy) {
              await orderDetailsNotifier.takeBuyOrder(orderId, fiatAmount);
            } else {
              final lndAddress = _lndAddressController.text.trim();
              await orderDetailsNotifier.takeSellOrder(orderId, fiatAmount,
                  lndAddress.isEmpty ? null : lndAddress);
            }
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
