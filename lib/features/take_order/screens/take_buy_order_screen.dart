import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/app/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/take_order/providers/order_notifier_providers.dart';
import 'package:mostro_mobile/features/take_order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/features/take_order/widgets/buyer_info.dart';
import 'package:mostro_mobile/features/take_order/widgets/seller_info.dart';
import 'package:mostro_mobile/presentation/widgets/currency_text_field.dart';
import 'package:mostro_mobile/presentation/widgets/exchange_rate_widget.dart';
import 'package:mostro_mobile/providers/exchange_service_provider.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;

class TakeBuyOrderScreen extends ConsumerWidget {
  final NostrEvent initialOrder;
  final TextEditingController _satsAmountController = TextEditingController();
  final TextEditingController _lndAdrress = TextEditingController();

  TakeBuyOrderScreen({super.key, required this.initialOrder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderDetailsState =
        ref.watch(takeBuyOrderNotifierProvider(initialOrder.orderId!));

    switch (orderDetailsState.action) {

      case actions.Action.takeBuy:
        return _buildContent(context, ref);
      case actions.Action.payInvoice:
        //return _buildLightningInvoice(context, orderDetailsState, ref);
      default:
        return const Center(child: Text('Order not found'));
    }
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: OrderAppBar(
          title:
              '${initialOrder.orderType == OrderType.buy ? "SELL" : "BUY"} BITCOIN'),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              CustomCard(
                  padding: EdgeInsets.all(16),
                  child: SellerInfo(order: initialOrder)),
              const SizedBox(height: 16),
              _buildSellerAmount(ref),
              const SizedBox(height: 16),
              ExchangeRateWidget(currency: initialOrder.currency!),
              const SizedBox(height: 16),
              CustomCard(
                  padding: const EdgeInsets.all(16),
                  child: BuyerInfo(order: initialOrder)),
              const SizedBox(height: 16),
              _buildBuyerAmount(),
              const SizedBox(height: 16),
              _buildLnAddress(),
              const SizedBox(height: 16),
              _buildActionButtons(context, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSellerAmount(WidgetRef ref) {
    final exchangeRateAsyncValue =
        ref.watch(exchangeRateProvider(initialOrder.currency!));
    return exchangeRateAsyncValue.when(
      loading: () => const CircularProgressIndicator(),
      error: (error, _) => Text('Error: $error'),
      data: (exchangeRate) {
        return CustomCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${initialOrder.fiatAmount} ${initialOrder.currency} (${initialOrder.premium}%)',
                      style: const TextStyle(
                          color: AppTheme.cream1,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Text('${initialOrder.amount} sats',
                      style: const TextStyle(color: AppTheme.grey2)),
                ],
              )
            ],
          ),
        );
      },
    );
  }


  Widget _buildBuyerAmount() {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CurrencyTextField(controller: _satsAmountController, label: 'Sats'),
          const SizedBox(height: 8),
          Text('\$ ${initialOrder.amount}',
              style: const TextStyle(color: AppTheme.grey2)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLnAddress() {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.dark1,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextFormField(
              controller: _lndAdrress,
              style: const TextStyle(color: AppTheme.cream1),
              decoration: InputDecoration(
                border: InputBorder.none,
                labelText: "Enter a Lightning Address",
                labelStyle: const TextStyle(color: AppTheme.grey2),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a value';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    final orderDetailsNotifier =
        ref.read(takeBuyOrderNotifierProvider(initialOrder.orderId!).notifier);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.red1,
            ),
            child: const Text('CANCEL'),
          ),
        const SizedBox(width: 16),
        ElevatedButton(
            onPressed: () => orderDetailsNotifier.takeBuyOrder(
                initialOrder.orderId!, null),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mostroGreen,
            ),
            child: const Text('CONTINUE'),
          ),
      ],
    );
  }
}
