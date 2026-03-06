import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/services/logger_service.dart';

/// Full-screen QR code scanner that returns the scanned value via [Navigator.pop].
///
/// Usage:
/// ```dart
/// final result = await Navigator.push<String>(
///   context,
///   MaterialPageRoute(builder: (_) => const QrScannerScreen()),
/// );
/// ```
///
/// An optional [uriPrefix] can be supplied to filter scanned values; only
/// codes whose content starts with the prefix (case-insensitive) will be
/// accepted.
class QrScannerScreen extends StatefulWidget {
  /// When non-null, only QR codes whose content starts with this prefix
  /// (case-insensitive comparison) are accepted.
  final String? uriPrefix;

  const QrScannerScreen({super.key, this.uriPrefix});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const HeroIcon(HeroIcons.xMark, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          S.of(context)!.scanQrCode,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder<TorchState>(
              valueListenable: _controller.torchState,
              builder: (_, state, __) {
                return Icon(
                  state == TorchState.on ? Icons.flash_on : Icons.flash_off,
                  color: state == TorchState.on
                      ? AppTheme.activeColor
                      : Colors.white,
                );
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Overlay with scan area indicator
          _buildOverlay(),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final value = barcode.rawValue;
      if (value == null || value.isEmpty) continue;

      // Filter by prefix if specified
      if (widget.uriPrefix != null &&
          !value.toLowerCase().startsWith(widget.uriPrefix!.toLowerCase())) {
        continue;
      }

      _hasScanned = true;
      logger.i('QR code scanned successfully');
      if (mounted) {
        context.pop(value);
      }
      return;
    }
  }

  Widget _buildOverlay() {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withValues(alpha: 0.5),
        BlendMode.srcOut,
      ),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
