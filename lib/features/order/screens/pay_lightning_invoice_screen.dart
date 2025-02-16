import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/payment_request.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';
import 'package:mostro_mobile/shared/widgets/pay_lightning_invoice_widget.dart';

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
    final order = ref.read(orderNotifierProvider(widget.orderId));
    final lnInvoice = order.getPayload<PaymentRequest>()?.lnInvoice ?? '';
    final orderNotifier =
        ref.read(orderNotifierProvider(widget.orderId).notifier);

    return Scaffold(
        backgroundColor: AppTheme.dark1,
        appBar: OrderAppBar(title: 'Pay Lightning Invoice'),
        body: CustomCard(
          padding: const EdgeInsets.all(16),
          child: Material(
            color: AppTheme.dark2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PayLightningInvoiceWidget(
                    onSubmit: () async {},
                    onCancel: () async {
                      await orderNotifier.cancelOrder();
                    },
                    lnInvoice: lnInvoice),
              ],
            ),
          ),
        ));
  }
}
