import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/wallet/providers/nwc_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/services/nwc/nwc_exceptions.dart';

/// Payment status for the NWC auto-payment flow.
enum NwcPaymentStatus {
  /// Ready to pay — waiting for user to tap "Pay with Wallet".
  idle,

  /// Payment request sent to the wallet, waiting for response.
  paying,

  /// Payment completed successfully.
  success,

  /// Payment failed with an error.
  failed,
}

/// Widget that provides a "Pay with Wallet" button for NWC-connected wallets.
///
/// Shows payment progress and handles errors gracefully. Falls back to the
/// manual flow if payment fails.
class NwcPaymentWidget extends ConsumerStatefulWidget {
  /// The Lightning invoice to pay.
  final String lnInvoice;

  /// Amount in satoshis (for display).
  final int sats;

  /// Callback when payment succeeds (navigate away, etc.).
  final VoidCallback? onPaymentSuccess;

  /// Callback to switch to manual payment flow.
  final VoidCallback? onFallbackToManual;

  const NwcPaymentWidget({
    super.key,
    required this.lnInvoice,
    required this.sats,
    this.onPaymentSuccess,
    this.onFallbackToManual,
  });

  @override
  ConsumerState<NwcPaymentWidget> createState() => _NwcPaymentWidgetState();
}

class _NwcPaymentWidgetState extends ConsumerState<NwcPaymentWidget> {
  NwcPaymentStatus _status = NwcPaymentStatus.idle;
  String? _errorMessage;
  String? _preimage;

  Future<void> _payWithWallet() async {
    final nwcNotifier = ref.read(nwcProvider.notifier);

    setState(() {
      _status = NwcPaymentStatus.paying;
      _errorMessage = null;
    });

    try {
      logger.i('NWC: Paying invoice (${widget.sats} sats)...');
      final result = await nwcNotifier.payInvoice(widget.lnInvoice);

      if (!mounted) return;

      setState(() {
        _status = NwcPaymentStatus.success;
        _preimage = result.preimage;
      });

      logger.i('NWC: Payment successful! Preimage: ${result.preimage.substring(0, 8)}...');

      // Notify parent of success
      widget.onPaymentSuccess?.call();
    } on NwcResponseException catch (e) {
      if (!mounted) return;
      logger.w('NWC: Payment failed with error code ${e.code}: ${e.message}');

      setState(() {
        _status = NwcPaymentStatus.failed;
        _errorMessage = _getUserFriendlyError(e);
      });
    } on NwcTimeoutException catch (_) {
      if (!mounted) return;
      logger.w('NWC: Payment timed out');

      setState(() {
        _status = NwcPaymentStatus.failed;
        _errorMessage = S.of(context)!.nwcPaymentTimeout;
      });
    } catch (e) {
      if (!mounted) return;
      logger.e('NWC: Payment failed unexpectedly: $e');

      setState(() {
        _status = NwcPaymentStatus.failed;
        _errorMessage = S.of(context)!.nwcPaymentFailed;
      });
    }
  }

  String _getUserFriendlyError(NwcResponseException e) {
    switch (e.code) {
      case NwcErrorCode.insufficientBalance:
        return S.of(context)!.nwcInsufficientBalance;
      case NwcErrorCode.paymentFailed:
        return S.of(context)!.nwcPaymentFailed;
      case NwcErrorCode.rateLimited:
        return S.of(context)!.nwcRateLimited;
      case NwcErrorCode.quotaExceeded:
        return S.of(context)!.nwcQuotaExceeded;
      default:
        return e.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildPaymentArea(),
        if (_status == NwcPaymentStatus.failed) ...[
          const SizedBox(height: 12),
          _buildFallbackButton(),
        ],
      ],
    );
  }

  Widget _buildPaymentArea() {
    switch (_status) {
      case NwcPaymentStatus.idle:
        return _buildPayButton();
      case NwcPaymentStatus.paying:
        return _buildPayingIndicator();
      case NwcPaymentStatus.success:
        return _buildSuccessIndicator();
      case NwcPaymentStatus.failed:
        return _buildErrorIndicator();
    }
  }

  Widget _buildPayButton() {
    final nwcState = ref.watch(nwcProvider);
    final balanceSats = nwcState.balanceSats;
    final hasEnoughBalance =
        balanceSats == null || balanceSats >= widget.sats;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: hasEnoughBalance ? _payWithWallet : null,
            icon: const Icon(LucideIcons.wallet, size: 20),
            label: Text(
              S.of(context)!.payWithWallet,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mostroGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (balanceSats != null) ...[
          const SizedBox(height: 8),
          Text(
            '${S.of(context)!.walletBalance}: ${_formatSats(balanceSats)} sats',
            style: TextStyle(
              color: hasEnoughBalance
                  ? AppTheme.cream1.withAlpha(153)
                  : Colors.red.shade300,
              fontSize: 13,
            ),
          ),
          if (!hasEnoughBalance)
            Text(
              S.of(context)!.nwcInsufficientBalance,
              style: TextStyle(color: Colors.red.shade300, fontSize: 13),
            ),
        ],
      ],
    );
  }

  Widget _buildPayingIndicator() {
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
            S.of(context)!.nwcPaymentSending,
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

  Widget _buildSuccessIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.dark1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.mostroGreen.withAlpha(128)),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.checkCircle, color: AppTheme.mostroGreen, size: 48),
          const SizedBox(height: 12),
          Text(
            S.of(context)!.nwcPaymentSuccess,
            style: const TextStyle(
              color: AppTheme.mostroGreen,
              fontSize: 18,
              fontWeight: FontWeight.w600,
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
          if (_preimage != null) ...[
            const SizedBox(height: 8),
            Text(
              'Preimage: ${_preimage!.substring(0, 16)}...',
              style: TextStyle(
                color: AppTheme.cream1.withAlpha(102),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
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
            _errorMessage ?? S.of(context)!.nwcPaymentFailed,
            style: const TextStyle(color: Colors.red, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _status = NwcPaymentStatus.idle;
                _errorMessage = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mostroGreen,
            ),
            child: Text(S.of(context)!.nwcRetryPayment),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackButton() {
    return TextButton.icon(
      onPressed: widget.onFallbackToManual,
      icon: const Icon(LucideIcons.qrCode, size: 16),
      label: Text(S.of(context)!.nwcPayManually),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.cream1.withAlpha(179),
      ),
    );
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
