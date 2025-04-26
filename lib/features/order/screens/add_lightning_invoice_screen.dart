import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
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
    final orderId = widget.orderId;
    final order = ref.watch(eventProvider(orderId));

    final amount = order?.amount;

    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: OrderAppBar(title: 'Add Lightning Invoice'),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.dark2,
                borderRadius: BorderRadius.circular(20),
              ),
              child: AddLightningInvoiceWidget(
                controller: invoiceController,
                onSubmit: () async {
                  final invoice = invoiceController.text.trim();
                  if (invoice.isNotEmpty) {
                    final orderNotifier = ref
                        .read(orderNotifierProvider(widget.orderId).notifier);
                    try {
                      await orderNotifier.sendInvoice(
                          widget.orderId, invoice, int.parse(amount));
                      context.go('/');
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
                  final orderNotifier =
                      ref.read(orderNotifierProvider(widget.orderId).notifier);
                  try {
                    await orderNotifier.cancelOrder();
                      context.go('/');
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Failed to cancel order: ${e.toString()}'),
                      ),
                    );
                  }
                },
                amount: int.parse(amount!),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
