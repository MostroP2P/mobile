import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/wallet/providers/nwc_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/services/nwc/nwc_exceptions.dart' show NwcResponseException, NwcTimeoutException, NwcErrorCode;

/// Invoice generation status for the NWC auto-invoice flow.
enum NwcInvoiceStatus {
  /// Ready — waiting for user to tap "Generate with Wallet".
  idle,

  /// Invoice creation request sent to the wallet, waiting for response.
  generating,

  /// Invoice generated successfully, awaiting user confirmation.
  generated,

  /// Invoice generation failed with an error.
  failed,
}

/// Widget that provides a "Generate with Wallet" button for NWC-connected wallets.
///
/// Generates a Lightning invoice via NWC's `make_invoice` method and allows
/// the user to confirm before submitting it to Mostro. Falls back to the
/// manual flow if generation fails.
class NwcInvoiceWidget extends ConsumerStatefulWidget {
  /// Amount in satoshis for the invoice.
  final int sats;

  /// Order ID for display context.
  final String orderId;

  /// Callback when the user confirms the generated invoice.
  /// Receives the bolt11 invoice string.
  final ValueChanged<String> onInvoiceConfirmed;

  /// Callback to switch to manual invoice input flow.
  final VoidCallback? onFallbackToManual;

  const NwcInvoiceWidget({
    super.key,
    required this.sats,
    required this.orderId,
    required this.onInvoiceConfirmed,
    this.onFallbackToManual,
  });

  @override
  ConsumerState<NwcInvoiceWidget> createState() => _NwcInvoiceWidgetState();
}

class _NwcInvoiceWidgetState extends ConsumerState<NwcInvoiceWidget> {
  NwcInvoiceStatus _status = NwcInvoiceStatus.idle;
  String? _errorMessage;
  String? _generatedInvoice;

  Future<void> _generateInvoice() async {
    final nwcNotifier = ref.read(nwcProvider.notifier);

    setState(() {
      _status = NwcInvoiceStatus.generating;
      _errorMessage = null;
    });

    try {
      logger.i('NWC: Generating invoice for ${widget.sats} sats...');
      final result = await nwcNotifier.makeInvoice(
        widget.sats,
        description: 'Mostro order ${widget.orderId}',
      );

      if (!mounted) return;

      final invoice = result.invoice;
      if (invoice == null || invoice.isEmpty) {
        logger.w('NWC: Wallet returned empty invoice');
        setState(() {
          _status = NwcInvoiceStatus.failed;
          _errorMessage = S.of(context)!.nwcInvoiceFailed;
        });
        return;
      }

      setState(() {
        _status = NwcInvoiceStatus.generated;
        _generatedInvoice = invoice;
      });

      logger.i('NWC: Invoice generated successfully');
    } on NwcResponseException catch (e) {
      if (!mounted) return;
      logger.w(
          'NWC: Invoice generation failed with code ${e.code}: ${e.message}');

      setState(() {
        _status = NwcInvoiceStatus.failed;
        _errorMessage = _getUserFriendlyError(e);
      });
    } on NwcTimeoutException catch (_) {
      if (!mounted) return;
      logger.w('NWC: Invoice generation timed out');

      setState(() {
        _status = NwcInvoiceStatus.failed;
        _errorMessage = S.of(context)!.nwcInvoiceTimeout;
      });
    } catch (e) {
      if (!mounted) return;
      logger.e('NWC: Invoice generation failed unexpectedly: $e');

      setState(() {
        _status = NwcInvoiceStatus.failed;
        _errorMessage = S.of(context)!.nwcInvoiceFailed;
      });
    }
  }

  String _getUserFriendlyError(NwcResponseException e) {
    switch (e.code) {
      case NwcErrorCode.rateLimited:
        return S.of(context)!.nwcRateLimited;
      case NwcErrorCode.quotaExceeded:
        return S.of(context)!.nwcQuotaExceeded;
      default:
        logger.w('NWC: Unhandled error code ${e.code}: ${e.message}');
        return S.of(context)!.nwcInvoiceFailed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildInvoiceArea(),
        if (_status == NwcInvoiceStatus.failed) ...[
          const SizedBox(height: 12),
          _buildFallbackButton(),
        ],
      ],
    );
  }

  Widget _buildInvoiceArea() {
    switch (_status) {
      case NwcInvoiceStatus.idle:
        return _buildGenerateButton();
      case NwcInvoiceStatus.generating:
        return _buildGeneratingIndicator();
      case NwcInvoiceStatus.generated:
        return _buildGeneratedConfirmation();
      case NwcInvoiceStatus.failed:
        return _buildErrorIndicator();
    }
  }

  Widget _buildGenerateButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _generateInvoice,
            icon: const Icon(LucideIcons.wallet, size: 20),
            label: Text(
              S.of(context)!.nwcGenerateWithWallet,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mostroGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_formatSats(widget.sats)} sats',
          style: TextStyle(
            color: AppTheme.cream1.withAlpha(153),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildGeneratingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.dark1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.mostroGreen.withAlpha(77)),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: AppTheme.mostroGreen,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            S.of(context)!.nwcInvoiceGenerating,
            style: const TextStyle(
              color: AppTheme.cream1,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatSats(widget.sats)} sats',
            style: TextStyle(
              color: AppTheme.cream1.withAlpha(153),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratedConfirmation() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.dark1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.mostroGreen.withAlpha(128)),
      ),
      child: Column(
        children: [
          const Icon(
            LucideIcons.checkCircle,
            color: AppTheme.mostroGreen,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            S.of(context)!.nwcInvoiceGenerated,
            style: const TextStyle(
              color: AppTheme.mostroGreen,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatSats(widget.sats)} sats',
            style: const TextStyle(
              color: AppTheme.cream1,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _truncateInvoice(_generatedInvoice),
            style: TextStyle(
              color: AppTheme.cream1.withAlpha(102),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _generatedInvoice != null
                  ? () => widget.onInvoiceConfirmed(_generatedInvoice!)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mostroGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                S.of(context)!.nwcConfirmInvoice,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.dark1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withAlpha(128)),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.alertCircle, color: Colors.red, size: 40),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? S.of(context)!.nwcInvoiceFailed,
            style: const TextStyle(color: Colors.red, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _status = NwcInvoiceStatus.idle;
                _errorMessage = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mostroGreen,
            ),
            child: Text(S.of(context)!.nwcRetryInvoice),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackButton() {
    return TextButton.icon(
      onPressed: widget.onFallbackToManual,
      icon: const Icon(LucideIcons.edit, size: 16),
      label: Text(S.of(context)!.nwcEnterManually),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.cream1.withAlpha(179),
      ),
    );
  }

  String _truncateInvoice(String? invoice) {
    if (invoice == null || invoice.isEmpty) return '';
    if (invoice.length <= 40) return invoice;
    return '${invoice.substring(0, 20)}...${invoice.substring(invoice.length - 20)}';
  }

  String _formatSats(int sats) {
    if (sats >= 1000000) {
      return '${(sats / 1000000).toStringAsFixed(2)}M';
    } else if (sats >= 1000) {
      return '${(sats / 1000).toStringAsFixed(1)}K';
    }
    return sats.toString();
  }
}
