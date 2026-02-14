import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/features/wallet/providers/nwc_provider.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';
import 'package:mostro_mobile/shared/widgets/nwc_payment_widget.dart';
import 'package:mostro_mobile/shared/widgets/pay_lightning_invoice_widget.dart';
import 'package:mostro_mobile/generated/l10n.dart';

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
    final fiatAmount = orderState.order?.fiatAmount.toString() ?? '0';
    final fiatCode = orderState.order?.fiatCode ?? '';
    final orderNotifier =
        ref.watch(orderNotifierProvider(widget.orderId).notifier);

    final nwcState = ref.watch(nwcProvider);
    final isNwcConnected = nwcState.status == NwcStatus.connected;
    final showNwcPayment = isNwcConnected && !_manualMode && lnInvoice.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: OrderAppBar(title: S.of(context)!.payLightningInvoice),
      body: CustomCard(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: AppTheme.dark2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showNwcPayment) ...[
                // NWC auto-payment flow
                Text(
                  S.of(context)!.payInvoiceToContinue(
                    sats.toString(),
                    fiatCode,
                    fiatAmount,
                    widget.orderId,
                  ),
                  style: const TextStyle(color: AppTheme.cream1, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                NwcPaymentWidget(
                  lnInvoice: lnInvoice,
                  sats: sats,
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
                    ),
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
                  sats: sats,
                  fiatAmount: fiatAmount,
                  fiatCode: fiatCode,
                  orderId: widget.orderId,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
