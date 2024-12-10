import 'package:flutter/material.dart';
import 'package:mostro_mobile/features/take_order/notifiers/take_buy_order_state.dart';
import 'package:qr_flutter/qr_flutter.dart';

class LightningInvoice extends StatelessWidget {
  final TakeBuyOrderState state;

  const LightningInvoice({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
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
        TextButton(
          child: const Text('CANCEL', style: TextStyle(color: Colors.white)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
