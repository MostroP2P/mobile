import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mostro_mobile/generated/l10n.dart';

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
        Text(
          S.of(context)!.payInvoiceToContinue,
          style: const TextStyle(color: AppTheme.cream1, fontSize: 18),
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
              return Center(
                child: Text(
                  S.of(context)!.failedToGenerateQR,
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.lnInvoice));
                widget.logger
                    .i('Copied LN Invoice to clipboard: ${widget.lnInvoice}');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(S.of(context)!.invoiceCopiedToClipboard),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: Text(S.of(context)!.copyButton),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mostroGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  // Try to launch Lightning URL directly first
                  final uri = Uri.parse('lightning:${widget.lnInvoice}');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                    widget.logger.i(
                        'Launched Lightning wallet with invoice: ${widget.lnInvoice}');
                  } else {
                    // Fallback to generic share if no Lightning apps available
                    // lightning: URL scheme is not necessary then
                    await Share.share(widget.lnInvoice);
                    widget.logger.i(
                        'Shared LN Invoice via share sheet: ${widget.lnInvoice}');
                  }
                } catch (e) {
                  widget.logger.e('Failed to share LN Invoice: $e');
                  if (mounted) {
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        // ignore: use_build_context_synchronously
                        content: Text(S.of(context)!.failedToShareInvoice),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.share),
              label: Text(S.of(context)!.shareButton),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mostroGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
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
              child: Text(S.of(context)!.cancel),
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
              child: Text(S.of(context)!.done),
            ),
          ],
        ),
      ],
    );
  }
}
