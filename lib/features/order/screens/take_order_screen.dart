import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/features/order/widgets/seller_info.dart';
import 'package:mostro_mobile/shared/widgets/currency_text_field.dart';
import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';

class TakeOrderScreen extends ConsumerWidget {
  final String orderId;
  final OrderType orderType;
  final TextEditingController _fiatAmountController = TextEditingController();
  final TextEditingController _lndAddressController = TextEditingController();
  final TextTheme textTheme = AppTheme.theme.textTheme;
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
                _buildPaymentMethod(order),
                const SizedBox(height: 16),
                if ((orderType == OrderType.sell && order.amount != '0') ||
                    order.fiatAmount.maximum != null)
                  _buildBuyerAmount(int.tryParse(order.amount!)),
                _buildLnAddress(),
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
        final sats = (100000000 / exchangeRate) * order.fiatAmount.minimum;
        return CustomCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${order.fiatAmount} ${order.currency} (${order.premium}%)',
                    style: textTheme.displayLarge,
                  ),
                  Text(
                    '${NumberFormat.currency(
                      symbol: '',
                      decimalDigits: 2,
                    ).format(sats)} sats',
                    style: const TextStyle(color: AppTheme.cream1),
                  ),
                  Text(
                    '1 BTC = ${NumberFormat.currency(
                      symbol: '',
                      decimalDigits: 2,
                    ).format(exchangeRate)} ${order.currency}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentMethod(NostrEvent order) {
    String method = order.paymentMethods.isNotEmpty
        ? order.paymentMethods[0]
        : 'No payment method';

    String methods = order.paymentMethods.join('\n');

    return CustomCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: HeroIcon(
                _getPaymentMethodIcon(method),
                style: HeroIconStyle.outline,
                color: AppTheme.cream1,
                size: 16,
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                methods,
                style: AppTheme.theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ));
  }

  HeroIcons _getPaymentMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'wire transfer':
      case 'transferencia bancaria':
        return HeroIcons.buildingLibrary;
      case 'revolut':
        return HeroIcons.creditCard;
      default:
        return HeroIcons.banknotes;
    }
  }

  Widget _buildBuyerAmount(int? amount) {
    return Column(children: [
      CustomCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CurrencyTextField(
                controller: _fiatAmountController,
                label: 'Enter a Fiat amount'),
            const SizedBox(height: 8),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ]);
  }

  Widget _buildLnAddress() {
    return Column(
      children: [
        CustomCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _lndAddressController,
                style: const TextStyle(color: AppTheme.cream1),
                decoration: InputDecoration(
                  labelText: "Enter a Lightning Address",
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a value';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildActionButtons(
      BuildContext context, WidgetRef ref, String orderId) {
    final orderDetailsNotifier =
        ref.read(orderNotifierProvider(orderId).notifier);

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
        // Take Order
        ElevatedButton(
          onPressed: () async {
            final fiatAmount = int.tryParse(_fiatAmountController.text.trim());
            if (orderType == OrderType.buy) {
              await orderDetailsNotifier.takeBuyOrder(orderId, fiatAmount);
            } else {
              final lndAddress = _lndAddressController.text.trim();
              await orderDetailsNotifier.takeSellOrder(
                  orderId, fiatAmount, lndAddress.isEmpty ? null : lndAddress);
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
