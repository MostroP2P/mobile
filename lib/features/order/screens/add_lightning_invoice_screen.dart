import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';
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

  Future<NostrEvent?>? _orderFuture;

  @override
  void initState() {
    super.initState();
    final orderRepo = ref.read(orderRepositoryProvider);
    _orderFuture = orderRepo.getOrderById(widget.orderId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: OrderAppBar(title: 'Add Lightning Invoice'),
      body: FutureBuilder<NostrEvent?>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load order: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          } else {
            final order = snapshot.data;
            if (order == null) {
              return const Center(
                child: Text(
                  'Order not found',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            final amount = order.amount;
            return CustomCard(
              padding: const EdgeInsets.all(16),
              child: Material(
                color: AppTheme.dark1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AddLightningInvoiceWidget(
                    controller: invoiceController,
                    onSubmit: () async {
                      final invoice = invoiceController.text.trim();
                      if (invoice.isNotEmpty) {
                        final orderRepo = ref.read(orderRepositoryProvider);
                        try {
                          // Here you would call your method to send or update the invoice.

                          context.go('/');
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Failed to update invoice: ${e.toString()}'),
                            ),
                          );
                        }
                      }
                    },
                    onCancel: () async {
                      final orderRepo = ref.read(orderRepositoryProvider);
                      try {
                        await orderRepo.deleteOrder(order.id!);
                        if (!mounted) return;
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
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
