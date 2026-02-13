import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/generated/l10n.dart';

/// Displays the wallet balance in sats with a refresh button.
class WalletBalanceWidget extends StatelessWidget {
  final int? balanceSats;
  final VoidCallback? onRefresh;

  const WalletBalanceWidget({
    super.key,
    this.balanceSats,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.zap,
                  color: AppTheme.activeColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  S.of(context)!.walletBalance,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (onRefresh != null)
                  IconButton(
                    onPressed: onRefresh,
                    icon: const Icon(
                      LucideIcons.refreshCw,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                    tooltip: S.of(context)!.refreshBalance,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                balanceSats != null
                    ? '⚡ ${_formatBalance(balanceSats!)} sats'
                    : '⚡ -- sats',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBalance(int sats) {
    // Format with thousand separators
    final str = sats.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
