import 'package:flutter/material.dart';
import 'package:mostro_mobile/app/app_theme.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class LightningInvoiceInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const LightningInvoiceInput({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<LightningInvoiceInput> createState() => _LightningInvoiceInputState();
}

class _LightningInvoiceInputState extends State<LightningInvoiceInput> {
  final MobileScannerController _controller = MobileScannerController();

  final boxFit = BoxFit.contain;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scanWindow = Rect.fromCenter(
      center:
          MediaQuery.of(context).size.center(Offset.zero).translate(0, -100),
      width: 300,
      height: 200,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MobileScanner(
          controller: _controller,
          scanWindow: scanWindow,
          fit: boxFit,
          onDetect: (barcode) {
            if (barcode.raw != null) {
              final String invoice = barcode.barcodes.first.rawValue!;
              widget.controller.text = invoice;
              // Once detected, immediately return the scanned invoice
            }
          },
          errorBuilder: (context, error, child) {
            return Center(
              child: Text(
                'Error: $error',
                style: const TextStyle(color: Colors.red),
              ),
            );
          },
        ),
        Positioned.fromRect(
          rect: scanWindow,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.greenAccent, width: 2),
              color: Colors.black.withOpacity(0.1),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Please enter a Lightning Invoice:",
          style: const TextStyle(color: AppTheme.cream1, fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('invoiceTextField'),
          controller: widget.controller,
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
                key: const Key('cancelInvoiceButton'),
                onPressed: widget.onCancel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('CANCEL'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                key: const Key('submitInvoiceButton'),
                onPressed: widget.onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.mostroGreen,
                ),
                child: const Text('SUBMIT'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
