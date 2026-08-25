import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/order/providers/market_check_provider.dart';
import 'package:mostro_mobile/features/order/providers/settlement_anchor_provider.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/features/wallet/providers/nwc_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/widgets/add_lightning_invoice_widget.dart';
import 'package:mostro_mobile/shared/widgets/nwc_invoice_widget.dart';
import 'package:mostro_mobile/shared/widgets/invoice_header.dart';
import 'package:mostro_mobile/shared/widgets/invoice_notice.dart';
import 'package:mostro_mobile/shared/widgets/ln_address_confirmation_widget.dart';
import 'package:mostro_mobile/shared/utils/market_quote.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/utils/snack_bar_helper.dart';
import 'package:mostro_mobile/services/logger_service.dart';

class AddLightningInvoiceScreen extends ConsumerStatefulWidget {
  final String orderId;

  /// Pre-configured Lightning Address to confirm, if available.
  final String? lnAddress;

  const AddLightningInvoiceScreen({
    super.key,
    required this.orderId,
    this.lnAddress,
  });

  @override
  ConsumerState<AddLightningInvoiceScreen> createState() =>
      _AddLightningInvoiceScreenState();
}

class _AddLightningInvoiceScreenState
    extends ConsumerState<AddLightningInvoiceScreen> {
  final TextEditingController invoiceController = TextEditingController();

  /// Whether the user chose to enter the invoice manually (fallback from NWC or LN address).
  bool _manualMode = false;

  /// The market gap the user chose to invoice past, if any.
  ///
  /// The refusal rests on a third-party rate, which can be stale or simply
  /// disagree, so it is not a verdict the screen should be able to impose
  /// with no way past it. Held as the quote they agreed to rather than as a
  /// flag: the node can republish the order and the rate can refresh while
  /// this screen stays mounted, and consent to one pair of figures is not
  /// consent to whatever replaces them.
  MarketOverride? _marketOverride;

  @override
  void dispose() {
    invoiceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderId = widget.orderId;
    final mostroOrderAsync = ref.watch(mostroOrderStreamProvider(orderId));

    return mostroOrderAsync.when(
      data: (mostroMessage) {
        final orderPayload = mostroMessage?.getPayload<Order>();
        final amount = orderPayload?.amount;
        final fiatAmount = orderPayload?.fiatAmount.toString() ?? '0';
        final fiatCode = orderPayload?.fiatCode ?? '';
        final orderIdValue = orderPayload?.id ?? orderId;
        // Trade summary shown by every flow: trade type, who took the order,
        // amounts, order id and the counterpart reputation (when received).
        // Adding an invoice always means the user is the buyer, but not always
        // the maker: taking a sell order and retrying after a failed payout
        // land here too.
        final session = ref.watch(sessionProvider(orderId));
        final orderState = ref.watch(orderNotifierProvider(orderId));
        final header = InvoiceHeader(
          userIsSeller: session?.role == Role.seller,
          sats: amount ?? 0,
          fiatAmount: fiatAmount,
          fiatCode: fiatCode,
          orderId: orderIdValue,
          takenByCounterpart: counterpartTookYourOrder(
            kind: orderState.order?.kind ?? orderPayload?.kind,
            role: session?.role,
            status: orderState.status,
          ),
          reputation: orderState.peerReputation,
        );

        // What this order should pay out, re-derived from the terms the node
        // signed: the amount in its kind-38383 order event, less the buyer's
        // half of the fee rate in its kind-38385 one. The figure above came
        // from the message asking for the invoice, and an invoice minted for
        // it is what the trade settles at.
        //
        // Null on either side means a figure has not arrived yet, not that
        // the request is wrong, so the screen only refuses on an actual
        // disagreement between two amounts it holds.
        final expectedSats = ref.watch(anchoredBuyerAmountProvider(orderId));
        final blocked =
            amount != null && expectedSats != null && amount != expectedSats;

        // Nothing to derive from means the request goes unchecked. The node
        // publishes both inputs and can withhold either, so this is a state
        // it can put the screen into rather than only an unlucky race: say so
        // instead of letting the absence of a refusal read as a confirmation.
        final unverified = amount != null && expectedSats == null;

        // A market-price order's sats were resolved by the node after the
        // take, so the check above only establishes that its own figures
        // agree. Re-price it against a rate the node does not control.
        final market = ref.watch(marketCheckProvider(orderId));
        final offMarket = !blocked && (market?.isOffMarket ?? false);

        // Adding an invoice is always the buyer's side of the trade. A payout
        // below the quote is the direction that shorts them, and the quote is
        // the only protection a market-price settlement has, so it is refused
        // until they say otherwise.
        final marketOverridden =
            market != null && (_marketOverride?.covers(orderId, market) ?? false);
        final marketBlocked =
            offMarket && !marketOverridden && market!.isAdverseTo(Role.buyer);
        final marketCaution = offMarket && !marketBlocked;

        final headerBlock = (unverified || marketCaution)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  if (unverified) ...[
                    const SizedBox(height: 16),
                    InvoiceNotice.caution(
                      title: S.of(context)!.invoiceTermsUnverifiedTitle,
                      body: S.of(context)!.invoiceTermsUnverifiedBody,
                    ),
                  ],
                  if (marketCaution) ...[
                    const SizedBox(height: 16),
                    InvoiceNotice.caution(
                      title: S.of(context)!.invoiceOffMarketTitle,
                      body: S.of(context)!.invoiceOffMarketBody(
                            market!.settledSats.toString(),
                            market.quotedSats.toString(),
                          ),
                    ),
                  ],
                ],
              )
            : header;

        final nwcState = ref.watch(nwcProvider);
        final isNwcConnected = nwcState.status == NwcStatus.connected;
        final showLnAddressConfirmation =
            widget.lnAddress != null && !_manualMode;
        final showNwcInvoice = isNwcConnected &&
            !_manualMode &&
            !showLnAddressConfirmation &&
            (amount ?? 0) > 0;

        return Scaffold(
          backgroundColor: AppTheme.dark1,
          appBar: OrderAppBar(title: S.of(context)!.addLightningInvoice),
          body: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(context).viewPadding.bottom,
            ),
            child: marketBlocked
                ? _buildMarketBlockedFlow(
                    header: headerBlock,
                    orderId: orderId,
                    settledSats: market.settledSats,
                    quotedSats: market.quotedSats,
                  )
                : blocked
                    ? _buildBlockedFlow(
                        header: headerBlock,
                        requestedSats: amount,
                        expectedSats: expectedSats,
                      )
                    : showLnAddressConfirmation
                        ? _buildLnAddressConfirmation(header: headerBlock)
                        : showNwcInvoice
                            ? _buildNwcInvoiceFlow(
                                header: headerBlock,
                                amount: amount ?? 0,
                                orderIdValue: orderIdValue,
                              )
                            : AddLightningInvoiceWidget(
                            controller: invoiceController,
                            onSubmit: () async {
                              final invoice = invoiceController.text.trim();
                              if (invoice.isNotEmpty) {
                                await _submitInvoice(invoice, amount);
                              }
                            },
                            onCancel: () async {
                              await _cancelOrder();
                            },
                            amount: amount ?? 0,
                            fiatAmount: fiatAmount,
                            fiatCode: fiatCode,
                            orderId: orderIdValue,
                            header: headerBlock,
                          ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildLnAddressConfirmation({required Widget header}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 24),
        LnAddressConfirmationWidget(
          lightningAddress: widget.lnAddress!,
          onConfirm: () async {
            await _submitLnAddress(widget.lnAddress!);
          },
          onManualFallback: () {
            setState(() => _manualMode = true);
          },
        ),
        const Spacer(),
        _buildCancelButton(),
      ],
    );
  }

  Future<void> _submitLnAddress(String lnAddress) async {
    final orderNotifier =
        ref.read(orderNotifierProvider(widget.orderId).notifier);
    try {
      logger.d('User confirmed Lightning address for order ${widget.orderId}');
      await orderNotifier.sendInvoice(widget.orderId, lnAddress, null);
      if (mounted) context.go('/');
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

  Widget _buildNwcInvoiceFlow({
    required Widget header,
    required int amount,
    required String orderIdValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 24),
        NwcInvoiceWidget(
          sats: amount,
          orderId: orderIdValue,
          onInvoiceConfirmed: (invoice) async {
            await _submitInvoice(invoice, amount);
          },
          onFallbackToManual: () {
            setState(() => _manualMode = true);
          },
        ),
        const Spacer(),
        _buildCancelButton(),
      ],
    );
  }

  /// Shown instead of every invoice flow when the amount asked for is not the
  /// amount this order should pay out.
  ///
  /// A refusal rather than a warning: an invoice minted here is what the
  /// trade settles at, and there is no confirming a figure the signed terms
  /// contradict.
  /// Shown when the settlement sits off the market rate in the node's favour.
  ///
  /// A refusal with a way past it: the quote comes from a third party and can
  /// be stale or simply disagree, so the screen states the gap and leaves the
  /// decision with the user rather than making it for them.
  Widget _buildMarketBlockedFlow({
    required Widget header,
    required String orderId,
    required int settledSats,
    required int quotedSats,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 24),
        InvoiceNotice.refusal(
          title: S.of(context)!.invoiceOffMarketTitle,
          body: S.of(context)!.invoiceOffMarketBlockedBody(
                settledSats.toString(),
                quotedSats.toString(),
              ),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                await _cancelOrder();
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red,
              ),
              child: Text(S.of(context)!.cancel),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () => setState(() => _marketOverride = MarketOverride(
                    orderId: orderId,
                    settledSats: settledSats,
                    quotedSats: quotedSats,
                  )),
              child: Text(S.of(context)!.invoiceContinueAnyway),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBlockedFlow({
    required Widget header,
    required int requestedSats,
    required int expectedSats,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 24),
        InvoiceNotice.refusal(
          title: S.of(context)!.invoiceRequestMismatchTitle,
          body: S.of(context)!.invoiceRequestMismatchBody(
                requestedSats.toString(),
                expectedSats.toString(),
              ),
        ),
        const Spacer(),
        _buildCancelButton(),
      ],
    );
  }

  Widget _buildCancelButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: () async {
            await _cancelOrder();
          },
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.red,
          ),
          child: Text(S.of(context)!.cancel),
        ),
      ],
    );
  }

  Future<void> _submitInvoice(String invoice, int? amount) async {
    final orderNotifier =
        ref.read(orderNotifierProvider(widget.orderId).notifier);
    try {
      await orderNotifier.sendInvoice(widget.orderId, invoice, amount);
      if (mounted) context.go('/');
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
}
