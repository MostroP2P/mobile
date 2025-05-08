import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/data/models/order.dart';
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
    final mostroOrderAsync = ref.watch(mostroOrderStreamProvider(orderId));

    return mostroOrderAsync.when(
      data: (mostroMessage) {
        final orderPayload = mostroMessage?.getPayload<Order>();
        final amount = orderPayload?.amount;

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
                              widget.orderId, invoice, amount);
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
                    amount: amount!,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}
