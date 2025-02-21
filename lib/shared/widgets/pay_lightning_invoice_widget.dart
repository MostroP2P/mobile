import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PayLightningInvoiceWidget extends StatefulWidget {
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final Logger logger = Logger();
  final String lnInvoice;

  PayLightningInvoiceWidget({
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
          style: TextStyle(color: AppTheme.cream1, fontSize: 18),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(8.0),
          color: AppTheme.cream1,
          child: QrImageView(
            data: widget.lnInvoice,
            version: QrVersions.auto,
            size: 250.0,
            backgroundColor: AppTheme.cream1,
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
            widget.logger
                .i('Copied LN Invoice to clipboard: ${widget.lnInvoice}');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invoice copied to clipboard'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copy Invoice'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.mostroGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Open Wallet Button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.mostroGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          onPressed: widget.onSubmit,
          child: const Text('OPEN WALLET'),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                context.go('/');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mostroGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('DONE'),
            ),
          ],
        ),
      ],
    );
  }
}
