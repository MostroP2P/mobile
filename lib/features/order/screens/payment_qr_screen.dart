import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as action;


class PaymentQrScreen extends ConsumerWidget {
  final String orderId;

  const PaymentQrScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(orderNotifierProvider(orderId));

    return Scaffold(
      backgroundColor: const Color(0xFF1D212C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('PAYMENT', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/'),
        ),
      ),
      body: _buildBody(context, ref, state),
      bottomNavigationBar: const BottomNavBar(), // from your code
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, MostroMessage state) {
    switch (state.action) {
      case action.Action.notFound:
        return const Center(child: CircularProgressIndicator());

      case action.Action.payInvoice:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Pay this invoice to continue the exchange',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),

            // Possibly insert your QR code or something
            // e.g. QrImage(...)

            const SizedBox(height: 20),
            Text(
              'Expires in: ',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8CC541),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () {
                //ref.read(paymentQrProvider.notifier).openWallet();
              },
              child: const Text('OPEN WALLET'),
            ),
            const SizedBox(height: 20),
            TextButton(
              child: const Text('CANCEL', style: TextStyle(color: Colors.white)),
              onPressed: () => context.go('/'),
            ),
          ],
        );

      default:
        return Center(
          child: Text('Unknown error: ${state.action}',
              style: const TextStyle(color: Colors.white)),
        );
    }
  }
}
