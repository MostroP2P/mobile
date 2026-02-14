import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/generated/l10n.dart';

/// Displays a payment receipt after a successful NWC payment.
///
/// Shows the amount paid, fees (if available), preimage, and timestamp.
class NwcPaymentReceiptWidget extends StatelessWidget {
  /// Amount paid in satoshis.
  final int amountSats;

  /// Fees paid in millisatoshis (from wallet response).
  final int? feesPaidMsats;

  /// Payment preimage (proof of payment).
  final String? preimage;

  /// Timestamp of the payment.
  final DateTime timestamp;

  /// Callback when the user dismisses the receipt.
  final VoidCallback? onDismiss;

  const NwcPaymentReceiptWidget({
    super.key,
    required this.amountSats,
    this.feesPaidMsats,
    this.preimage,
    required this.timestamp,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final feesSats = feesPaidMsats != null ? (feesPaidMsats! ~/ 1000) : null;
    final totalSats = feesSats != null ? amountSats + feesSats : amountSats;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.dark1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.mostroGreen.withAlpha(128)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Success icon
          const Icon(
            LucideIcons.checkCircle2,
            color: AppTheme.mostroGreen,
            size: 56,
          ),
          const SizedBox(height: 12),
          Text(
            S.of(context)!.nwcPaymentSuccess,
            style: const TextStyle(
              color: AppTheme.mostroGreen,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),

          // Amount breakdown
          _buildReceiptRow(
            context,
            S.of(context)!.nwcReceiptAmount,
            '${_formatSats(amountSats)} sats',
          ),
          if (feesSats != null && feesSats > 0)
            _buildReceiptRow(
              context,
              S.of(context)!.nwcReceiptFees,
              '${_formatSats(feesSats)} sats',
            ),
          if (feesSats != null && feesSats > 0)
            _buildReceiptRow(
              context,
              S.of(context)!.nwcReceiptTotal,
              '${_formatSats(totalSats)} sats',
              isBold: true,
            ),

          const SizedBox(height: 8),
          _buildReceiptRow(
            context,
            S.of(context)!.nwcReceiptTimestamp,
            _formatTimestamp(timestamp),
          ),

          // Preimage
          if (preimage != null && preimage!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: AppTheme.grey2, height: 1),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.of(context)!.nwcPreimageLabel,
                        style: TextStyle(
                          color: AppTheme.cream1.withAlpha(153),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _truncate(preimage!, 32),
                        style: TextStyle(
                          color: AppTheme.cream1.withAlpha(179),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    LucideIcons.copy,
                    size: 16,
                    color: AppTheme.cream1.withAlpha(153),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: preimage!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(S.of(context)!.nwcPreimageCopied),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],

          if (onDismiss != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.mostroGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(S.of(context)!.nwcReceiptDone),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReceiptRow(
    BuildContext context,
    String label,
    String value, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.cream1.withAlpha(153),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.cream1,
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  String _truncate(String value, int keep) {
    if (value.length <= keep) return value;
    return '${value.substring(0, keep)}...';
  }

  String _formatSats(int sats) {
    if (sats >= 1000000) {
      return '${(sats / 1000000).toStringAsFixed(2)}M';
    } else if (sats >= 1000) {
      return '${(sats / 1000).toStringAsFixed(1)}K';
    }
    return sats.toString();
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} '
        '${_pad(dt.hour)}:${_pad(dt.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
