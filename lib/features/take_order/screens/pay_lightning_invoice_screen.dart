import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/app/app_theme.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/take_order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';
import 'package:qr_flutter/qr_flutter.dart';

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

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: CustomCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Pay this invoice to continue the exchange',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      color: Colors.white,
                      child: QrImageView(
                        data: lnInvoice,
                        version: QrVersions.auto,
                        size: 250.0,
                        backgroundColor: Colors.white,
                        errorStateBuilder: (cxt, err) {
                          return const Center(
                            child: Text(
                              'Failed to generate QR code',
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: lnInvoice));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invoice copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Invoice'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8CC541),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Open Wallet Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8CC541),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Open wallet feature not implemented.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const Text('OPEN WALLET'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        final orderRepo = ref.read(orderRepositoryProvider);
                        try {
                          // We assume "cancel order" means deleting from DB
                          if (order.id != null) {
                            await orderRepo.deleteOrder(order.id!);
                          }
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('CANCEL'),
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
