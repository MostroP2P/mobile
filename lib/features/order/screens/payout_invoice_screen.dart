import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/features/wallet/providers/nwc_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/utils/snack_bar_helper.dart';
import 'package:mostro_mobile/shared/widgets/add_lightning_invoice_widget.dart';
import 'package:mostro_mobile/shared/widgets/nwc_invoice_widget.dart';
import 'package:mostro_mobile/features/order/providers/market_check_provider.dart';
import 'package:mostro_mobile/features/order/providers/settlement_anchor_provider.dart';
import 'package:mostro_mobile/shared/widgets/invoice_notice.dart';

/// Invoice screen for collecting the sats of a settled order.
///
/// The trade itself is over, so this is not the add-invoice of a take: there is
/// no counterpart to introduce, no Lightning address shortcut (it may be what
/// broke the payout in the first place) and nothing left to cancel.
///
/// The settlement checks run here too — an invoice minted here is still what
/// the payout settles at — but every one of them cautions rather than refuses.
/// Nothing left to cancel cuts both ways: the user has already given up their
/// side of the trade, the hold invoice is settled, and collecting is all that
/// remains. A screen that refused to mint would leave them unable to collect
/// at all, with no path back. Naming the gap is the strongest thing that can
/// be done here without stranding an honest trade.
class PayoutInvoiceScreen extends ConsumerStatefulWidget {
  final String orderId;

  /// Latest order snapshot, used for the amounts shown in the header.
  final Order? order;

  const PayoutInvoiceScreen({
    super.key,
    required this.orderId,
    this.order,
  });

  @override
  ConsumerState<PayoutInvoiceScreen> createState() =>
      _PayoutInvoiceScreenState();
}

class _PayoutInvoiceScreenState extends ConsumerState<PayoutInvoiceScreen> {
  final TextEditingController invoiceController = TextEditingController();

  /// Set when the user falls back from the NWC wallet to typing an invoice.
  bool _manualMode = false;

  @override
  void dispose() {
    invoiceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    // Only what is displayed falls back to zero; an unknown amount travels as
    // null instead of claiming the payout is worth nothing.
    final sats = order?.amount ?? 0;
    final fiatAmount = order?.fiatAmount.toString() ?? '0';
    final fiatCode = order?.fiatCode ?? '';
    final orderIdValue = order?.id ?? widget.orderId;

    // What the order's signed terms say this payout is worth: the order
    // amount less the buyer's half of the fee, re-derived rather than taken
    // from the figure the node put in the message.
    final expectedSats = ref.watch(anchoredBuyerAmountProvider(widget.orderId));
    final mismatch =
        sats > 0 && expectedSats != null && sats != expectedSats;

    // Nothing to re-derive from. The node publishes both inputs and can
    // withhold either, so silence here would read as a confirmation.
    final unverified = sats > 0 && expectedSats == null;

    // A market-price order's sats were resolved by the node after the take,
    // so the check above only establishes that its own figures agree.
    final market = ref.watch(marketCheckProvider(widget.orderId));
    final offMarket = market.check?.isOffMarket ?? false;
    final marketUnavailable = market.isUnavailable;

    final nwcState = ref.watch(nwcProvider);
    final showNwcInvoice =
        nwcState.status == NwcStatus.connected && !_manualMode && sats > 0;

    final notices = <Widget>[
      if (mismatch)
        InvoiceNotice.caution(
          title: S.of(context)!.payoutAmountMismatchTitle,
          body: S.of(context)!.payoutAmountMismatchBody(
                sats.toString(),
                expectedSats.toString(),
              ),
        ),
      if (unverified)
        InvoiceNotice.caution(
          title: S.of(context)!.invoiceTermsUnverifiedTitle,
          body: S.of(context)!.invoiceTermsUnverifiedBody,
        ),
      if (offMarket)
        InvoiceNotice.caution(
          title: S.of(context)!.invoiceOffMarketTitle,
          body: S.of(context)!.invoiceOffMarketBody(
                market.check!.settledSats.toString(),
                market.check!.quotedSats.toString(),
              ),
        ),
      if (marketUnavailable)
        InvoiceNotice.caution(
          title: S.of(context)!.invoiceMarketRateUnavailableTitle,
          body: S.of(context)!.invoiceMarketRateUnavailableBody,
        ),
    ];

    final header = notices.isEmpty
        ? _PayoutHeader(
            sats: sats,
            fiatAmount: fiatAmount,
            fiatCode: fiatCode,
            orderId: orderIdValue,
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PayoutHeader(
                sats: sats,
                fiatAmount: fiatAmount,
                fiatCode: fiatCode,
                orderId: orderIdValue,
              ),
              for (final notice in notices) ...[
                const SizedBox(height: 16),
                notice,
              ],
            ],
          );

    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: OrderAppBar(title: S.of(context)!.collectYourSats),
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: showNwcInvoice
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  const SizedBox(height: 24),
                  NwcInvoiceWidget(
                    sats: sats,
                    orderId: orderIdValue,
                    onInvoiceConfirmed: (invoice) async {
                      // Same nullable amount as the manual path: only the
                      // display falls back to zero, never what is submitted.
                      await _submitInvoice(invoice, order?.amount);
                    },
                    onFallbackToManual: () {
                      setState(() => _manualMode = true);
                    },
                  ),
                ],
              )
            : AddLightningInvoiceWidget(
                controller: invoiceController,
                onSubmit: () async {
                  final invoice = invoiceController.text.trim();
                  if (invoice.isNotEmpty) {
                    await _submitInvoice(invoice, order?.amount);
                  }
                },
                amount: sats,
                fiatAmount: fiatAmount,
                fiatCode: fiatCode,
                orderId: orderIdValue,
                header: header,
              ),
      ),
    );
  }

  Future<void> _submitInvoice(String invoice, int? amount) async {
    final orderNotifier =
        ref.read(orderNotifierProvider(widget.orderId).notifier);
    try {
      await orderNotifier.sendInvoice(widget.orderId, invoice, amount);
      if (mounted) context.go('/trade_detail/${widget.orderId}');
    } catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          SnackBarHelper.showTopSnackBar(
            context,
            S.of(context)!.failedToUpdateInvoice(e.toString()),
          );
        });
      }
    }
  }
}

/// Header of the payout screen: what will be paid and for which order. It says
/// nothing about the counterpart or about a failed payment, because the screen
/// is also reached while the payout is still on its way.
class _PayoutHeader extends StatelessWidget {
  final int sats;
  final String fiatAmount;
  final String fiatCode;
  final String orderId;

  const _PayoutHeader({
    required this.sats,
    required this.fiatAmount,
    required this.fiatCode,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    const bodyStyle = TextStyle(color: AppTheme.textPrimary, fontSize: 16);
    final boldStyle = bodyStyle.copyWith(fontWeight: FontWeight.w600);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          s.payoutInvoiceInstruction(sats.toString(), fiatAmount, fiatCode),
          style: bodyStyle,
        ),
        const SizedBox(height: 12),
        // Text.rich (not RichText) so the line inherits the theme font
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${s.orderIdLabel}: ', style: boldStyle),
              TextSpan(text: orderId),
            ],
          ),
          style: bodyStyle,
        ),
      ],
    );
  }
}
