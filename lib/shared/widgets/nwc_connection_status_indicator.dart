import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/wallet/providers/nwc_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';

/// A compact indicator showing NWC wallet connection health.
///
/// Shows a colored dot and optional label:
/// - Green dot: connected and healthy
/// - Yellow dot: connected but communication issues detected
/// - Red dot: disconnected or error
/// - Hidden: no wallet configured
class NwcConnectionStatusIndicator extends ConsumerWidget {
  /// Whether to show the text label alongside the dot.
  final bool showLabel;

  /// Whether to show the wallet balance next to the status.
  final bool showBalance;

  const NwcConnectionStatusIndicator({
    super.key,
    this.showLabel = false,
    this.showBalance = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nwcState = ref.watch(nwcProvider);

    // Don't show anything if no wallet is configured
    if (nwcState.status == NwcStatus.disconnected) {
      return const SizedBox.shrink();
    }

    final Color dotColor;
    final String statusText;
    final IconData icon;

    switch (nwcState.status) {
      case NwcStatus.connected:
        if (nwcState.connectionHealthy) {
          dotColor = Colors.green;
          statusText = S.of(context)!.walletConnected;
          icon = LucideIcons.wallet;
        } else {
          dotColor = Colors.orange;
          statusText = S.of(context)!.nwcConnectionUnstable;
          icon = LucideIcons.wifiOff;
        }
      case NwcStatus.connecting:
        dotColor = Colors.orange;
        statusText = S.of(context)!.nwcReconnecting;
        icon = LucideIcons.refreshCw;
      case NwcStatus.error:
        dotColor = Colors.red;
        statusText = S.of(context)!.nwcConnectionError;
        icon = LucideIcons.alertTriangle;
      case NwcStatus.disconnected:
        return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: dotColor),
        if (showLabel) ...[
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              color: dotColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (showBalance && nwcState.balanceSats != null) ...[
          const SizedBox(width: 8),
          Text(
            '${_formatSats(nwcState.balanceSats!)} sats',
            style: TextStyle(
              color: AppTheme.cream1.withAlpha(153),
              fontSize: 12,
            ),
          ),
        ],
      ],
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
