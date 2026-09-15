import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/enums.dart' as enums;
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/utils/snack_bar_helper.dart';

class PayBondInvoiceScreen extends ConsumerWidget {
  final String orderId;

  const PayBondInvoiceScreen({super.key, required this.orderId});

  Future<void> _confirmAndCancel(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final s = S.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.backgroundCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: Text(
          s.cancelTradeDialogTitle,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          s.areYouSureCancel,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              s.no,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.activeColor,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            child: Text(
              s.yes,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    final orderNotifier = ref.read(orderNotifierProvider(orderId).notifier);
    context.go('/');
    await orderNotifier.cancelOrder();
  }

  Future<void> _shareInvoice(BuildContext context, String lnInvoice) async {
    final messenger = ScaffoldMessenger.of(context);
    final mediaQuery = MediaQuery.of(context);
    final errorMessage = S.of(context)!.failedToShareInvoice;

    try {
      final uri = Uri.parse('lightning:$lnInvoice');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        logger.i('Launched Lightning wallet with bond invoice');
      } else {
        await Share.share(lnInvoice);
        logger.i('Shared bond invoice via share sheet');
      }
    } catch (e) {
      logger.e('Failed to share bond invoice: $e');
      SnackBarHelper.showTopSnackBarAsync(
        messenger: messenger,
        screenHeight: mediaQuery.size.height,
        statusBarHeight: mediaQuery.padding.top,
        message: errorMessage,
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context)!;
    final orderState = ref.watch(orderNotifierProvider(orderId));
    // Only the invoice of the bond phase belongs on this screen. The order
    // notifier is keyed by order id, so an escrow invoice from an earlier
    // take of the same order could otherwise be rendered here as a bond —
    // long after Mostro cancelled it node-side (#731).
    final isBondPhase = orderState.action == enums.Action.payBondInvoice ||
        orderState.status == enums.Status.waitingTakerBond;
    final lnInvoice =
        isBondPhase ? orderState.paymentRequest?.lnInvoice ?? '' : '';
    final bondAmount =
        isBondPhase ? orderState.paymentRequest?.order?.amount : null;
    // A maker creating an order pays the bond before it is published, so the
    // copy must warn them to keep the screen open or the order won't be created.
    final isMakerBond = ref
            .read(sessionNotifierProvider.notifier)
            .getSessionByOrderId(orderId)
            ?.bondPending ??
        false;
    final explanation = isMakerBond ? s.bondExplanationMaker : s.bondExplanation;

    if (lnInvoice.isEmpty) {
      // No invoice to show — and the reason decides what to tell the user.
      // Saying "expired, take the order again" in all three cases is what
      // could make a maker abandon a bond that was merely still loading.
      final cycleEnded =
          OrderState.endsTradeCycle(orderState.status) &&
              orderState.status != enums.Status.pending;
      // `pending` here is the notifier's initial state as well: the maker bond
      // arrives on AddOrderNotifier and only reaches this provider once its
      // sync() has read the message, so the first frames legitimately have
      // nothing to render.
      final stillLoading = !cycleEnded &&
          (orderState.status == enums.Status.pending ||
              orderState.status == enums.Status.waitingTakerBond);

      if (stillLoading) {
        return _EmptyBondState(
          title: s.bondScreenTitle,
          icon: null,
          message: s.bondInvoicePending,
        );
      }

      if (cycleEnded) {
        return _EmptyBondState(
          title: s.bondScreenTitle,
          icon: Icons.hourglass_disabled,
          message: s.bondInvoiceUnavailable,
          // The copy says "go back", so go back when there is a stack to pop.
          actionLabel: s.close,
          onAction: (context) =>
              context.canPop() ? context.pop() : context.go('/'),
        );
      }

      // Past the bond phase: the bond is paid and the trade moved on.
      return _EmptyBondState(
        title: s.bondScreenTitle,
        icon: Icons.check_circle_outline,
        message: s.bondAlreadyPaid,
        actionLabel: s.goToTrade,
        onAction: (context) => context.go('/trade_detail/$orderId'),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: OrderAppBar(title: s.bondScreenTitle),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              explanation,
              style: const TextStyle(
                color: AppTheme.cream1,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            if (bondAmount != null && bondAmount > 0) ...[
              const SizedBox(height: 16),
              Text(
                s.bondPayInvoicePrompt(bondAmount),
                style: const TextStyle(
                  color: AppTheme.cream1,
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(8.0),
                color: AppTheme.cream1,
                child: QrImageView(
                  data: lnInvoice,
                  version: QrVersions.auto,
                  size: 250.0,
                  backgroundColor: AppTheme.cream1,
                  errorStateBuilder: (cxt, err) {
                    return Center(
                      child: Text(
                        s.failedToGenerateQR,
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: lnInvoice.isEmpty
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: lnInvoice));
                          logger.i('Copied bond invoice to clipboard');
                          SnackBarHelper.showTopSnackBar(
                            context,
                            s.invoiceCopiedToClipboard,
                            duration: const Duration(seconds: 2),
                          );
                        },
                  icon: const Icon(Icons.copy),
                  label: Text(s.copy),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.mostroGreen,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: lnInvoice.isEmpty
                      ? null
                      : () => _shareInvoice(context, lnInvoice),
                  icon: const Icon(Icons.share),
                  label: Text(s.share),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.mostroGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => _confirmAndCancel(context, ref),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.red,
                  ),
                  child: Text(s.cancel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The bond screen with no invoice to show: one message, at most one action.
class _EmptyBondState extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String message;
  final String? actionLabel;
  final void Function(BuildContext context)? onAction;

  const _EmptyBondState({
    required this.title,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: OrderAppBar(title: title),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Icon(icon, color: AppTheme.textSecondary, size: 48)
            else
              const CircularProgressIndicator(color: AppTheme.mostroGreen),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.cream1,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => onAction!(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.mostroGreen,
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
