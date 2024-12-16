import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/app/app_theme.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/take_order/providers/order_notifier_providers.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';

class AddLightningInvoiceScreen extends ConsumerWidget {
  final String orderId;
  final int sats = 0;

  const AddLightningInvoiceScreen({super.key, required this.orderId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderDetailsNotifier =
        ref.read(takeSellOrderNotifierProvider(orderId).notifier);
    final state =
        ref.read(takeSellOrderNotifierProvider(orderId));

    var amount =
        (state.payload is Order) ? (state.payload as Order).amount : 0;

    final TextEditingController invoiceController = TextEditingController();
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
                        orderDetailsNotifier.sendInvoice(orderId, invoice, sats);
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
}
