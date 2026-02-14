import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/wallet/providers/nwc_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/services/nwc/nwc_client.dart';

/// A widget that listens to NWC payment notifications and shows
/// in-app snackbar notifications when payments are received or sent.
///
/// Wrap this around a top-level widget (e.g., in the app scaffold)
/// to receive real-time payment notifications.
class NwcNotificationListener extends ConsumerStatefulWidget {
  final Widget child;

  const NwcNotificationListener({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<NwcNotificationListener> createState() =>
      _NwcNotificationListenerState();
}

class _NwcNotificationListenerState
    extends ConsumerState<NwcNotificationListener> {
  StreamSubscription<NwcNotification>? _subscription;

  @override
  void initState() {
    super.initState();
    // Defer subscription to after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribe();
    });
  }

  void _subscribe() {
    final notifier = ref.read(nwcProvider.notifier);
    _subscription = notifier.notifications.listen(_onNotification);
  }

  void _onNotification(NwcNotification notification) {
    if (!mounted) return;

    final String message;
    final IconData icon;
    final Color color;
    final amountSats = notification.transaction.amount ~/ 1000;
    final formattedAmount = _formatSats(amountSats);

    switch (notification.notificationType) {
      case 'payment_received':
        message =
            S.of(context)!.nwcNotificationPaymentReceived(formattedAmount);
        icon = LucideIcons.arrowDownCircle;
        color = AppTheme.mostroGreen;
      case 'payment_sent':
        message = S.of(context)!.nwcNotificationPaymentSent(formattedAmount);
        icon = LucideIcons.arrowUpCircle;
        color = Colors.orange;
      default:
        return; // Ignore unknown notification types
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.dark2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withAlpha(128)),
        ),
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
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
