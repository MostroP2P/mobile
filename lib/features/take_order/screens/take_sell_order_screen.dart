import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/app/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/take_order/providers/order_notifier_providers.dart';
import 'package:mostro_mobile/features/take_order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/features/take_order/widgets/buyer_info.dart';
import 'package:mostro_mobile/features/take_order/widgets/completion_message.dart';
import 'package:mostro_mobile/features/take_order/widgets/seller_info.dart';
import 'package:mostro_mobile/presentation/widgets/currency_text_field.dart';
import 'package:mostro_mobile/presentation/widgets/exchange_rate_widget.dart';
import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;

class TakeSellOrderScreen extends ConsumerWidget {
  final String orderId;
  final TextEditingController _satsAmountController = TextEditingController();
  final TextEditingController _lndAdrress = TextEditingController();

  TakeSellOrderScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderDetailsState = ref.watch(takeSellOrderNotifierProvider(orderId));
    switch (orderDetailsState.action) {
      case actions.Action.takeSell:
        return _buildContent(context, ref);
      case actions.Action.addInvoice:
        return _buildLightningInvoiceInput(context, ref);
      case actions.Action.waitingSellerToPay:
        return _buildCompletionMessage();
      default:
        return const Center(child: Text('Order not found'));
    }
  }

  Widget _buildCompletionMessage() {
    final message = 'Order has been completed successfully!';
    return CompletionMessage(message: message);
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    final orderAsyncValue = ref.read(eventProvider(orderId));
    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: OrderAppBar(title: 'SELL BITCOIN'),
      body: orderAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (initialOrder) {
          // If order is null => show "Order not found"
          if (initialOrder == null) {
            return const Center(child: Text('Order not found'));
          }
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  CustomCard(
                      padding: EdgeInsets.all(16),
                      child: SellerInfo(order: initialOrder)),
                  const SizedBox(height: 16),
                  _buildSellerAmount(ref, initialOrder),
                  const SizedBox(height: 16),
                  ExchangeRateWidget(currency: initialOrder.currency!),
                  const SizedBox(height: 16),
                  CustomCard(
                      padding: const EdgeInsets.all(16),
                      child: BuyerInfo(order: initialOrder)),
                  const SizedBox(height: 16),
                  _buildBuyerAmount(initialOrder.amount!),
                  const SizedBox(height: 16),
                  _buildLnAddress(),
                  const SizedBox(height: 16),
                  _buildActionButtons(context, ref),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSellerAmount(WidgetRef ref, NostrEvent initialOrder) {
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

  Widget _buildLightningInvoiceInput(BuildContext context, WidgetRef ref) {
    final orderDetailsNotifier =
        ref.read(takeSellOrderNotifierProvider(orderId).notifier);
    final state = ref.watch(takeSellOrderNotifierProvider(orderId));
    final order = (state.payload is Order) ? state.payload as Order : null;

    final TextEditingController invoiceController = TextEditingController();
    final val = order?.amount;
    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: OrderAppBar(title: 'Add a Lightning Invoice'),
      body: CustomCard(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Please enter a Lightning Invoice for $val sats:",
                style: TextStyle(color: AppTheme.cream1, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: invoiceController,
                style: const TextStyle(color: AppTheme.cream1),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  labelText: "Lightning Invoice",
                  labelStyle: const TextStyle(color: AppTheme.grey2),
                  hintText: "Enter invoice here",
                  hintStyle: const TextStyle(color: AppTheme.grey2),
                  filled: true,
                  fillColor: AppTheme.dark1,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        context.go('/');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final invoice = invoiceController.text.trim();
                        if (invoice.isNotEmpty) {
                          orderDetailsNotifier.sendInvoice(
                              orderId, invoice, val);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.mostroGreen,
                      ),
                      child: const Text('SUBMIT'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBuyerAmount(String amount) {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CurrencyTextField(controller: _satsAmountController, label: 'Sats'),
          const SizedBox(height: 8),
          Text('\$ $amount', style: const TextStyle(color: AppTheme.grey2)),
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
        ref.read(takeSellOrderNotifierProvider(orderId).notifier);

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
          child: const Text('CANCEL', style: TextStyle(color: AppTheme.red2)),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: () =>
              orderDetailsNotifier.takeSellOrder(orderId, null, null),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.mostroGreen,
          ),
          child: const Text('CONTINUE'),
        ),
      ],
    );
  }
}
