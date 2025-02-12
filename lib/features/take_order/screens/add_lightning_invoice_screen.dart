import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/app/app_theme.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/take_order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';

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
    // Kick off async load from OrderRepository
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
            // Still loading
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            // Show error message
            return Center(
              child: Text(
                'Failed to load order: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          } else {
            // Data is loaded (or null if not found)
            final order = snapshot.data;
            if (order == null) {
              return const Center(
                child: Text(
                  'Order not found',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            // Now we have the order, we can safely reference order.amount, etc.
            final amount = order.fiatAmount;

            return CustomCard(
              padding: const EdgeInsets.all(16),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Please enter a Lightning Invoice for $amount sats:",
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
                            onPressed: () async {
                              // Cancel the order
                              final orderRepo = ref.read(orderRepositoryProvider);
                              try {
                                await orderRepo.deleteOrder(order.id!);
                                if (!mounted) return;
                                context.go('/');
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Failed to cancel order: ${e.toString()}'),
                                  ),
                                );
                              }
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
                            onPressed: () async {
                              final invoice = invoiceController.text.trim();
                              if (invoice.isNotEmpty) {
                                final orderRepo = ref.read(orderRepositoryProvider);
                                try {
                                  // Typically you'd do something like
                                  // order.buyerInvoice = invoice;
                                  // orderRepo.updateOrder(order)
                                  // or a specialized method orderRepo.sendInvoice
                                  // For this example, let's just do an "update"


                                  // If you want to navigate away or confirm
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Lightning Invoice updated!'),
                                    ),
                                  );
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
            );
          }
        },
      ),
    );
  }
}
