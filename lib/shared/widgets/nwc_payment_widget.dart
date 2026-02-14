import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/wallet/providers/nwc_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/services/nwc/nwc_exceptions.dart';
import 'package:mostro_mobile/shared/widgets/nwc_payment_receipt_widget.dart';

/// Payment status for the NWC auto-payment flow.
enum NwcPaymentStatus {
  /// Ready to pay — waiting for user to tap "Pay with Wallet".
  idle,

  /// Running pre-flight checks (balance verification).
  checking,

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
/// manual flow if payment fails. Includes pre-flight balance checks and
/// payment receipt display.
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
  int? _feesPaidMsats;
  DateTime? _paymentTimestamp;

  Future<void> _payWithWallet() async {
    final nwcNotifier = ref.read(nwcProvider.notifier);

    // Pre-flight balance check
    setState(() {
      _status = NwcPaymentStatus.checking;
      _errorMessage = null;
    });

    final hasBalance = await nwcNotifier.preFlightBalanceCheck(widget.sats);
    if (!mounted) return;

    if (!hasBalance) {
      setState(() {
        _status = NwcPaymentStatus.failed;
        _errorMessage = S.of(context)!.nwcInsufficientBalance;
      });
      return;
    }

    setState(() {
      _status = NwcPaymentStatus.paying;
    });

    try {
      logger.i('NWC: Paying invoice (${widget.sats} sats)...');
      final result = await nwcNotifier.payInvoice(widget.lnInvoice);

      if (!mounted) return;

      setState(() {
        _status = NwcPaymentStatus.success;
        _preimage = result.preimage;
        _feesPaidMsats = result.feesPaid;
        _paymentTimestamp = DateTime.now();
      });

      logger.i(
        _truncatePreimage(result.preimage, 8).isEmpty
            ? 'NWC: Payment successful! Preimage unavailable'
            : 'NWC: Payment successful! Preimage: ${_truncatePreimage(result.preimage, 8)}',
      );

      // Verify payment via lookup_invoice if payment_hash available
      _verifyPayment();

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

  /// Verifies payment via lookup_invoice for extra reliability.
  Future<void> _verifyPayment() async {
    try {
      final nwcNotifier = ref.read(nwcProvider.notifier);
      final result = await nwcNotifier.lookupInvoice(
        invoice: widget.lnInvoice,
      );
      if (result != null) {
        logger.i(
            'NWC: Payment verified via lookup_invoice (state: ${result.state})');
      }
    } catch (e) {
      logger.w('NWC: lookup_invoice verification failed: $e');
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
      case NwcPaymentStatus.checking:
        return _buildCheckingIndicator();
      case NwcPaymentStatus.paying:
        return _buildPayingIndicator();
      case NwcPaymentStatus.success:
        return _buildSuccessReceipt();
      case NwcPaymentStatus.failed:
        return _buildErrorIndicator();
    }
  }

  Widget _buildPayButton() {
    final nwcState = ref.watch(nwcProvider);
    final balanceSats = nwcState.balanceSats;
    final hasEnoughBalance = balanceSats == null || balanceSats >= widget.sats;

    return Column(
      children: [
        // Connection health warning
        if (nwcState.status == NwcStatus.connected &&
            !nwcState.connectionHealthy)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withAlpha(77)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.wifiOff, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.of(context)!.nwcConnectionUnstable,
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Low balance warning
        if (balanceSats != null && !hasEnoughBalance)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withAlpha(77)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.alertTriangle,
                    size: 16, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.of(context)!.nwcBalanceTooLow,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

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
        ],
      ],
    );
  }

  Widget _buildCheckingIndicator() {
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
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              color: AppTheme.mostroGreen,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            S.of(context)!.nwcCheckingBalance,
            style: const TextStyle(
              color: AppTheme.cream1,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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

  Widget _buildSuccessReceipt() {
    return NwcPaymentReceiptWidget(
      amountSats: widget.sats,
      feesPaidMsats: _feesPaidMsats,
      preimage: _preimage,
      timestamp: _paymentTimestamp ?? DateTime.now(),
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

  String _truncatePreimage(String? value, int keep) {
    if (value == null || value.isEmpty) return '';
    return value.length <= keep ? value : '${value.substring(0, keep)}...';
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
