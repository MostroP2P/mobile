import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/wallet/providers/nwc_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';

/// Card displayed in the Settings screen showing NWC wallet status.
///
/// Shows connected/disconnected state, wallet name when connected,
/// and navigates to wallet settings on tap.
class WalletStatusCard extends ConsumerWidget {
  const WalletStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nwcState = ref.watch(nwcProvider);
    final isConnected = nwcState.status == NwcStatus.connected;

    return Container(
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
                Icon(
                  LucideIcons.wallet,
                  color: isConnected
                      ? AppTheme.activeColor
                      : AppTheme.textSecondary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  S.of(context)!.wallet,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              S.of(context)!.walletDescription,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.push('/wallet_settings'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundInput,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isConnected ? LucideIcons.check : LucideIcons.plug,
                        color:
                            isConnected ? Colors.green : AppTheme.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isConnected
                                  ? (nwcState.walletAlias ??
                                      S.of(context)!.walletConnected)
                                  : S.of(context)!.walletDisconnected,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isConnected &&
                                nwcState.balanceSats != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '⚡ ${_formatSats(nwcState.balanceSats!)} ${S.of(context)!.sats}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSats(int sats) {
    if (sats >= 1000000) {
      return '${(sats / 1000000).toStringAsFixed(2)}M';
    } else if (sats >= 1000) {
      return '${(sats / 1000).toStringAsFixed(1)}k';
    }
    return sats.toString();
  }
}
