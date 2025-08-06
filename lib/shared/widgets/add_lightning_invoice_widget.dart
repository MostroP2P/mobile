import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class AddLightningInvoiceWidget extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final int amount;
  final String fiatAmount;
  final String fiatCode;
  final String orderId;

  const AddLightningInvoiceWidget({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.onCancel,
    required this.amount,
    required this.fiatAmount,
    required this.fiatCode,
    required this.orderId,
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
        Text(
          S.of(context)!.pleaseEnterLightningInvoiceFor(
            widget.amount.toString(),
            widget.fiatCode,
            widget.fiatAmount,
            widget.orderId,
          ),
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.backgroundInput,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextFormField(
            key: const Key('invoiceTextField'),
            controller: widget.controller,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: S.of(context)!.lightningInvoice,
              labelStyle: const TextStyle(color: AppTheme.textSecondary),
              hintText: S.of(context)!.enterInvoiceHere,
              hintStyle: const TextStyle(color: AppTheme.textSecondary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              alignLabelWithHint: true,
            ),
            maxLines: 6,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextButton(
                key: const Key('cancelInvoiceButton'),
                onPressed: widget.onCancel,
                child: Text(
                  S.of(context)!.cancel,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                key: const Key('submitInvoiceButton'),
                onPressed: widget.onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.activeColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                child: Text(
                  S.of(context)!.submit,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
