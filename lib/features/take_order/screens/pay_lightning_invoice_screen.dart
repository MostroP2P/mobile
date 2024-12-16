import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PayLightningInvoiceScreen extends StatelessWidget {
  final String orderId;

  const PayLightningInvoiceScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Pay this invoice to continue the exchange',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            QrImageView(
              data: '1234567890',
              version: QrVersions.auto,
              size: 200.0,
            ),
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
              onPressed: () {},
              child: const Text('OPEN WALLET'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                context.go('/');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('CANCEL'),
            ),
          ],
        ),
      ),
    );
  }
}
