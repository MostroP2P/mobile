import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/shared/widgets/clickable_text_widget.dart';

class AddLightningInvoiceWidget extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final int amount;

  const AddLightningInvoiceWidget({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.onCancel,
    required this.amount,
  });

  @override
  State<AddLightningInvoiceWidget> createState() =>
      _AddLightningInvoiceWidgetState();
}

class _AddLightningInvoiceWidgetState extends State<AddLightningInvoiceWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClickableText(
          leftText: 'Please enter a Lightning Invoice for: ',
          clickableText: '${widget.amount}',
          rightText: ' sats',
        ),
        const SizedBox(height: 16),
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
            alignLabelWithHint: true,
          ),
          maxLines: 6,
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
