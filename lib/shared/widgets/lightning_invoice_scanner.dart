import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class LightningInvoiceScanner extends StatefulWidget {
  const LightningInvoiceScanner({super.key});

  @override
  State<LightningInvoiceScanner> createState() =>
      _LightningInvoiceScannerState();
}

class _LightningInvoiceScannerState extends State<LightningInvoiceScanner> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.unrestricted,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If running on Linux, show an alternate widget
    if (defaultTargetPlatform == TargetPlatform.linux) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan not supported')),
        body: const Center(
          child: Text('QR scanning is not supported on Linux.'),
        ),
      );
    }

    // Define a scan window
    final scanWindow = Rect.fromCenter(
      center: MediaQuery.of(context).size.center(Offset.zero).translate(0, -100),
      width: 300,
      height: 200,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Lightning Invoice'),
      ),
      body: Stack(
        children: [
          // Wrap in a container with explicit height to ensure proper sizing.
          SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height,
            child: MobileScanner(
              controller: _controller,
              scanWindow: scanWindow,
              errorBuilder: (context, error, child) {
                return Center(
                  child: Text(
                    'Error: $error',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              },
            ),
          ),
          // Optional overlay to highlight the scan area
          Positioned.fromRect(
            rect: scanWindow,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 2),
                color: Colors.black.withValues(alpha: .1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
