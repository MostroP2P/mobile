import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/utils/bond_amounts.dart';
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
    final lnInvoice = orderState.paymentRequest?.lnInvoice ?? '';
    final bondAmount = orderState.paymentRequest?.order?.amount;

    // Held against the policy the node published in its kind-38385 event,
    // which is where it states that it charges bonds at all and how it sizes
    // them. Nothing gated this request on any of it, so the figure was
    // whatever the message said.
    //
    // The order's sats amount is what the node sizes the bond from. It has
    // none for a market-priced range order — each taker's bond follows their
    // own quote, which the node computes and never sends — so only the
    // advertised floor can be checked there.
    final info = ref.watch(orderRepositoryProvider).mostroInstance;
    final instance = info == null ? null : MostroInstance.fromEvent(info);
    final bondProblem = BondAmounts.problemWith(
      requestedSats: bondAmount,
      orderAmountSats: orderState.order?.amount,
      advertised: instance?.bondPolicy == BondPolicy.enabled,
      amountPct: instance?.bondAmountPct,
      baseAmountSats: instance?.bondBaseAmountSats,
    );
    // A maker creating an order pays the bond before it is published, so the
    // copy must warn them to keep the screen open or the order won't be created.
    final isMakerBond = ref
            .read(sessionNotifierProvider.notifier)
            .getSessionByOrderId(orderId)
            ?.bondPending ??
        false;
    final explanation =
        isMakerBond ? s.bondExplanationMaker : s.bondExplanation;

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
        child: bondProblem != null
            ? _BondPolicyNotice(
                problem: bondProblem,
                requestedSats: bondAmount ?? 0,
              )
            : Column(
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
                                Clipboard.setData(
                                    ClipboardData(text: lnInvoice));
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

/// Shown instead of the bond invoice when the request does not follow the
/// policy the node published.
///
/// A refusal: a bond is money held against the trade, and there is no
/// confirming a figure the node's own published policy does not yield.
class _BondPolicyNotice extends StatelessWidget {
  final BondProblem problem;
  final int requestedSats;

  const _BondPolicyNotice({
    required this.problem,
    required this.requestedSats,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final body = problem == BondProblem.notAdvertised
        ? s.bondPolicyNotAdvertisedBody
        : s.bondAmountMismatchBody(requestedSats.toString());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.statusError.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.statusError.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.statusError,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.bondPolicyMismatchTitle,
                  style: const TextStyle(
                    color: AppTheme.statusError,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
