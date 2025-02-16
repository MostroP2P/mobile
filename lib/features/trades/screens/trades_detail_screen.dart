import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/order/widgets/seller_info.dart';
import 'package:mostro_mobile/shared/widgets/currency_text_field.dart';
import 'package:mostro_mobile/shared/widgets/exchange_rate_widget.dart';
import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';

class TradeDetailScreen extends ConsumerWidget {
  final String orderId;
  final TextEditingController _fiatAmountController = TextEditingController();

  TradeDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsyncValue = ref.watch(eventProvider(orderId));

    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const HeroIcon(HeroIcons.arrowLeft, color: AppTheme.cream1),
        onPressed: () => context.go('/order_book'),
      ),
      title: Text(
        'TRADE DETAIL',
        style: AppTheme.theme.textTheme.displayLarge,
      ),
    ),
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
                  _buildBuyerAmount(int.tryParse(order.amount!)),
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

}
