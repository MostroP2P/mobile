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
import 'package:mostro_mobile/shared/widgets/nwc_payment_widget.dart';
import 'package:mostro_mobile/shared/widgets/pay_lightning_invoice_widget.dart';
import 'package:mostro_mobile/generated/l10n.dart';
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
    final expectedSats =
        ref.watch(anchoredSellerAmountProvider(widget.orderId)) ??
            orderState.order?.amount;

    final terms = InvoiceTerms.check(
      invoice: lnInvoice,
      expectedSats: expectedSats,
    );
    final blocked = lnInvoice.isNotEmpty && !terms.isPayable;
    final fiatAmount = orderState.order?.fiatAmount.toString() ?? '0';
    final fiatCode = orderState.order?.fiatCode ?? '';
    final orderNotifier =
        ref.watch(orderNotifierProvider(widget.orderId).notifier);

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
                    onPressed: () async {
                      context.go('/');
                      await orderNotifier.cancelOrder();
                    },
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
                    onPressed: () async {
                      context.go('/');
                      await orderNotifier.cancelOrder();
                    },
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
                onCancel: () async {
                  context.go('/');
                  await orderNotifier.cancelOrder();
                },
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.statusError.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.statusError.withValues(alpha: 0.3),
        ),
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
                  S.of(context)!.invoiceNotPayableTitle,
                  style: const TextStyle(
                    color: AppTheme.statusError,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _body(context),
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
