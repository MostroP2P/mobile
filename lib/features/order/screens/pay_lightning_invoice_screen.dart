import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/core/automation/automation_id.dart';
import 'package:mostro_mobile/core/automation/automation_ids.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/features/wallet/providers/nwc_provider.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/widgets/invoice_header.dart';
import 'package:mostro_mobile/shared/widgets/invoice_notice.dart';
import 'package:mostro_mobile/shared/widgets/nwc_payment_widget.dart';
import 'package:mostro_mobile/shared/widgets/pay_lightning_invoice_widget.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/utils/snack_bar_helper.dart';
import 'package:mostro_mobile/features/order/providers/market_check_provider.dart';
import 'package:mostro_mobile/features/order/providers/settlement_anchor_provider.dart';
import 'package:mostro_mobile/shared/utils/invoice_terms.dart';

class PayLightningInvoiceScreen extends ConsumerStatefulWidget {
  final String orderId;

  const PayLightningInvoiceScreen({super.key, required this.orderId});

  @override
  ConsumerState<PayLightningInvoiceScreen> createState() =>
      _PayLightningInvoiceScreenState();
}

class _PayLightningInvoiceScreenState
    extends ConsumerState<PayLightningInvoiceScreen> {
  /// Whether the user chose to pay manually (fallback from NWC).
  bool _manualMode = false;

  /// Cancels the trade, and only leaves the screen once that has gone
  /// through. Navigating first would strand the failure: `cancelOrder`
  /// rethrows, the screen is already gone, and the user is told nothing while
  /// the trade stays active. It is the only action offered after a refusal,
  /// so a silent failure there leaves no way forward at all.
  Future<void> _cancelOrder() async {
    final orderNotifier =
        ref.read(orderNotifierProvider(widget.orderId).notifier);
    try {
      await orderNotifier.cancelOrder();
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          SnackBarHelper.showTopSnackBar(
            context,
            S.of(context)!.failedToCancelOrder(e.toString()),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderNotifierProvider(widget.orderId));
    final lnInvoice = orderState.paymentRequest?.lnInvoice ?? '';
    final sats = orderState.order?.amount ?? 0;

    // What this payment should cost, preferably re-derived rather than
    // accepted. The node publishes the order amount in its kind-38383 event
    // and the fee rate in its kind-38385 one, and computes the hold invoice
    // from exactly those two; deriving the same figure holds the message to
    // the order the user actually chose, instead of only holding the message
    // to itself.
    //
    // Falling back to the message's own amount when either input is missing
    // is deliberate. The events arrive asynchronously and the message can win
    // the race, so treating "cannot derive" as "wrong" would refuse correct
    // payments on a slow relay. The fallback still reconciles the figure on
    // screen against the invoice, which is what a wallet will actually send.
    final anchoredSats = ref.watch(anchoredSellerAmountProvider(widget.orderId));
    final expectedSats = anchoredSats ?? orderState.order?.amount;

    final terms = InvoiceTerms.check(
      invoice: lnInvoice,
      expectedSats: expectedSats,
    );
    final blocked = lnInvoice.isNotEmpty && !terms.isPayable;
    final unverified =
        lnInvoice.isNotEmpty && !blocked && anchoredSats == null;

    // A market-price order's sats were resolved by the node after the take,
    // so the checks above only establish that its own figures agree. Re-price
    // it against a rate the node does not control.
    final market = ref.watch(marketCheckProvider(widget.orderId));
    final offMarket = !blocked && (market?.isOffMarket ?? false);
    final fiatAmount = orderState.order?.fiatAmount.toString() ?? '0';
    final fiatCode = orderState.order?.fiatCode ?? '';
    final nwcState = ref.watch(nwcProvider);
    final isNwcConnected = nwcState.status == NwcStatus.connected;
    final showNwcPayment =
        isNwcConnected && !_manualMode && lnInvoice.isNotEmpty;

    // Trade summary shown by every flow: trade type, who took the order,
    // amounts, order id and the counterpart reputation (when received).
    // Paying the hold invoice always means the user is the seller, but not
    // always the maker: taking a buy order lands here too.
    final session = ref.watch(sessionProvider(widget.orderId));
    final header = InvoiceHeader(
      userIsSeller: session?.role == null || session!.role == Role.seller,
      // The summary states what the trade is, so it takes the re-derived
      // figure over the one the message asserts. The two agree whenever the
      // node is honest, and where they do not the message is the side with
      // nothing behind it.
      sats: expectedSats ?? sats,
      fiatAmount: fiatAmount,
      fiatCode: fiatCode,
      orderId: widget.orderId,
      takenByCounterpart: counterpartTookYourOrder(
        kind: orderState.order?.kind,
        role: session?.role,
        status: orderState.status,
      ),
      reputation: orderState.peerReputation,
    );

    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: OrderAppBar(title: S.of(context)!.payLightningInvoice),
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
            if (unverified) ...[
              InvoiceNotice.caution(
                title: S.of(context)!.invoiceTermsUnverifiedTitle,
                body: S.of(context)!.invoiceTermsUnverifiedBody,
              ),
              const SizedBox(height: 16),
            ],
            if (offMarket) ...[
              InvoiceNotice.caution(
                title: S.of(context)!.invoiceOffMarketTitle,
                body: S.of(context)!.invoiceOffMarketBody(
                      market!.settledSats.toString(),
                      market.quotedSats.toString(),
                    ),
              ),
              const SizedBox(height: 16),
            ],
            if (blocked) ...[
              header,
              const SizedBox(height: 24),
              _InvoiceTermsNotice(
                  terms: terms, orderSats: expectedSats ?? sats),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _cancelOrder,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red,
                    ),
                    child: Text(S.of(context)!.cancel),
                  ).withAutomationId(AutomationIds.payCancel),
                ],
              ),
            ] else if (showNwcPayment) ...[
              // NWC auto-payment flow
              header,
              const SizedBox(height: 24),
              // Automation readout: the invoice being paid, so a black-box
              // driver can correlate the payment by hash without reading the
              // QR code. Invisible; screen readers get the invoice string.
              const SizedBox(width: 1, height: 1).withAutomationId(
                  AutomationIds.payInvoiceText,
                  merge: false,
                  label: lnInvoice),
              NwcPaymentWidget(
                lnInvoice: lnInvoice,
                // Read back off the invoice rather than the message that
                // carried it. The check above has already established the two
                // agree; taking it from here keeps the number on screen and
                // the number the wallet will send the same value.
                sats: terms.amountSats ?? sats,
                onPaymentSuccess: () {
                  // Payment succeeded — Mostro will update the order state
                  // automatically via the event stream. We just navigate home.
                  context.go('/');
                },
                onFallbackToManual: () {
                  setState(() => _manualMode = true);
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _cancelOrder,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red,
                    ),
                    child: Text(S.of(context)!.cancel),
                  ).withAutomationId(AutomationIds.payCancel),
                ],
              ),
            ] else ...[
              // Manual payment flow (original)
              PayLightningInvoiceWidget(
                onSubmit: () async {
                  context.go('/');
                },
                onCancel: _cancelOrder,
                lnInvoice: lnInvoice,
                // Read back off the invoice, as the NWC branch does. A wallet
                // scanning the QR honours the invoice, so the figure printed
                // next to it has to be the invoice's own or it is describing
                // a different payment than the one being made.
                sats: terms.amountSats ?? sats,
                fiatAmount: fiatAmount,
                fiatCode: fiatCode,
                orderId: widget.orderId,
                header: header,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Explains why an invoice will not be paid from this screen.
///
/// Every case is a refusal rather than a warning: there is no reading of an
/// unreadable invoice, or of one that leaves the amount to the wallet, that
/// makes paying it safe.
class _InvoiceTermsNotice extends StatelessWidget {
  final InvoiceTerms terms;
  final int orderSats;

  const _InvoiceTermsNotice({required this.terms, required this.orderSats});

  String _body(BuildContext context) {
    final s = S.of(context)!;
    switch (terms.problem) {
      case InvoiceTermsProblem.amountMismatch:
        return s.invoiceTermsMismatchBody(
          terms.amountSats?.toString() ?? '',
          orderSats.toString(),
        );
      case InvoiceTermsProblem.amountMissing:
        return s.invoiceAmountMissingBody;
      case InvoiceTermsProblem.termsUnknown:
        return s.invoiceTermsUnknownBody;
      case InvoiceTermsProblem.unreadable:
      case null:
        return s.invoiceUnreadableBody;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InvoiceNotice.refusal(
      title: S.of(context)!.invoiceNotPayableTitle,
      body: _body(context),
    );
  }
}
