import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';
import 'package:mostro_mobile/shared/widgets/add_lightning_invoice_widget.dart';

class AddLightningInvoiceScreen extends ConsumerStatefulWidget {
  final String orderId;

  const AddLightningInvoiceScreen({super.key, required this.orderId});

  @override
  ConsumerState<AddLightningInvoiceScreen> createState() =>
      _AddLightningInvoiceScreenState();
}

class _AddLightningInvoiceScreenState
    extends ConsumerState<AddLightningInvoiceScreen> {
  final TextEditingController invoiceController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final order = ref.read(orderNotifierProvider(widget.orderId));

    final amount = order.getPayload<Order>()?.amount;

    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: OrderAppBar(title: 'Add Lightning Invoice'),
      body: CustomCard(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: AppTheme.dark2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AddLightningInvoiceWidget(
              controller: invoiceController,
              onSubmit: () async {
                final invoice = invoiceController.text.trim();
                if (invoice.isNotEmpty) {
                  final orderNotifier =
                      ref.read(orderNotifierProvider(widget.orderId).notifier);
                  try {
                    await orderNotifier.sendInvoice(widget.orderId, invoice, amount);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Failed to update invoice: ${e.toString()}'),
                      ),
                    );
                  }
                }
              },
              onCancel: () async {
                final orderNotifier = ref.read(orderNotifierProvider(widget.orderId).notifier);
                try {
                  await orderNotifier.cancelOrder();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to cancel order: ${e.toString()}'),
                    ),
                  );
                }
              }, amount: amount!,
            ),
          ),
        ),
      ),
    );
  }
}
