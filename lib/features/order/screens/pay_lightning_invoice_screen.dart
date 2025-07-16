import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';
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
  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderNotifierProvider(widget.orderId));
    final lnInvoice = orderState.paymentRequest?.lnInvoice ?? '';
    final sats = orderState.order?.amount ?? 0;
    final fiatAmount = orderState.order?.fiatAmount.toString() ?? '0';
    final fiatCode = orderState.order?.fiatCode ?? '';
    final orderNotifier =
        ref.watch(orderNotifierProvider(widget.orderId).notifier);

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
                    orderId: widget.orderId),
              ],
            ),
          ),
        ));
  }
}
