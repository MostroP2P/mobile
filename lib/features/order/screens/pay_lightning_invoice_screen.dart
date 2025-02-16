import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/widgets/pay_lightning_invoice_widget.dart';

class PayLightningInvoiceScreen extends ConsumerStatefulWidget {
  final String orderId;

  const PayLightningInvoiceScreen({super.key, required this.orderId});

  @override
  ConsumerState<PayLightningInvoiceScreen> createState() =>
      _PayLightningInvoiceScreenState();
}

class _PayLightningInvoiceScreenState
    extends ConsumerState<PayLightningInvoiceScreen> {
  Future<NostrEvent?>? _orderFuture;

  @override
  void initState() {
    super.initState();
    // Kick off async load from the Encrypted DB
    final orderRepo = ref.read(orderRepositoryProvider);
    _orderFuture = orderRepo.getOrderById(widget.orderId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: OrderAppBar(title: 'Pay Lightning Invoice'),
      body: FutureBuilder<NostrEvent?>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show a loading indicator while fetching
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            // Error retrieving order
            return Center(
              child: Text(
                'Failed to load order: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          } else {
            final order = snapshot.data;
            // If the order isn't found or buyerInvoice is null/empty
            if (order == null) {
              return const Center(
                child: Text(
                  'Invalid payment request.',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              );
            }

            // We have a valid LN invoice in order.buyerInvoice
            final lnInvoice = '';
            // order.buyerInvoice!;

            return PayLightningInvoiceWidget(
                onSubmit: () async {}, onCancel: () async {}, lnInvoice: lnInvoice);
          }
        },
      ),
    );
  }
}
