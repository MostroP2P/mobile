import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PayLightningInvoiceWidget extends StatefulWidget {
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final String lnInvoice;

  const PayLightningInvoiceWidget({
    super.key,
    required this.onSubmit,
    required this.onCancel,
    required this.lnInvoice,
  });

  @override
  State<PayLightningInvoiceWidget> createState() =>
      _PayLightningInvoiceWidgetState();
}

class _PayLightningInvoiceWidgetState extends State<PayLightningInvoiceWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
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
            data: widget.lnInvoice,
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
            Clipboard.setData(ClipboardData(text: widget.lnInvoice));
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
          onPressed: widget.onSubmit,
          child: const Text('OPEN WALLET'),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: widget.onCancel,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text('CANCEL'),
        ),
      ],
    );
  }
}
