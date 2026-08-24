import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/screens/payout_invoice_screen.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/features/wallet/providers/nwc_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/widgets/add_lightning_invoice_widget.dart';
import 'package:mostro_mobile/shared/widgets/nwc_invoice_widget.dart';
import 'package:mostro_mobile/shared/widgets/invoice_header.dart';
import 'package:mostro_mobile/shared/widgets/ln_address_confirmation_widget.dart';
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
        final orderState = ref.watch(orderNotifierProvider(orderId));
        // A settled order is not asking for the invoice a take requires, but
        // for the payout one, which has its own screen. It deliberately ignores
        // `lnAddress`: the address may be what broke the payout to begin with.
        if (orderState.status.isPayoutInvoice) {
          return PayoutInvoiceScreen(
            orderId: orderId,
            // The stream only matches messages whose payload is an Order; the
            // notifier also keeps one carried by a PaymentRequest.
            order: orderPayload ?? orderState.order,
          );
        }
        final amount = orderPayload?.amount;
        final fiatAmount = orderPayload?.fiatAmount.toString() ?? '0';
        final fiatCode = orderPayload?.fiatCode ?? '';
        final orderIdValue = orderPayload?.id ?? orderId;
        // Trade summary shown by every flow: trade type, who took the order,
        // amounts, order id and the counterpart reputation (when received).
        // Adding an invoice always means the user is the buyer, but not always
        // the maker: taking a sell order lands here too.
        final session = ref.watch(sessionProvider(orderId));
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
            child: showLnAddressConfirmation
                ? _buildLnAddressConfirmation(header: header)
                : showNwcInvoice
                    ? _buildNwcInvoiceFlow(header: header)
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
                        header: header,
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

  Widget _buildNwcInvoiceFlow({required InvoiceHeader header}) {
    final amount = header.sats;
    final orderIdValue = header.orderId;
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
