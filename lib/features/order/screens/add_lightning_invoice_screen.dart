import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/features/wallet/providers/nwc_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/shared/widgets/add_lightning_invoice_widget.dart';
import 'package:mostro_mobile/shared/widgets/nwc_invoice_widget.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/utils/snack_bar_helper.dart';

class AddLightningInvoiceScreen extends ConsumerStatefulWidget {
  final String orderId;

  const AddLightningInvoiceScreen({super.key, required this.orderId});

  @override
  ConsumerState<AddLightningInvoiceScreen> createState() =>
      _AddLightningInvoiceScreenState();
}

class _AddLightningInvoiceScreenState
    extends ConsumerState<AddLightningInvoiceScreen> {
  final TextEditingController invoiceController = TextEditingController();

  /// Whether the user chose to enter the invoice manually (fallback from NWC).
  bool _manualMode = false;

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

        final nwcState = ref.watch(nwcProvider);
        final isNwcConnected = nwcState.status == NwcStatus.connected;
        final showNwcInvoice =
            isNwcConnected && !_manualMode && (amount ?? 0) > 0;

        return Scaffold(
          backgroundColor: AppTheme.backgroundDark,
          appBar: OrderAppBar(title: S.of(context)!.addLightningInvoice),
          body: Column(
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundCard,
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: showNwcInvoice
                      ? _buildNwcInvoiceFlow(
                          amount: amount ?? 0,
                          fiatAmount: fiatAmount,
                          fiatCode: fiatCode,
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
                        ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildNwcInvoiceFlow({
    required int amount,
    required String fiatAmount,
    required String fiatCode,
    required String orderIdValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.pleaseEnterLightningInvoiceFor(
                amount.toString(),
                fiatCode,
                fiatAmount,
                orderIdValue,
              ),
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
        NwcInvoiceWidget(
          sats: amount,
          fiatAmount: fiatAmount,
          fiatCode: fiatCode,
          orderId: orderIdValue,
          onInvoiceConfirmed: (invoice) async {
            await _submitInvoice(invoice, amount);
          },
          onFallbackToManual: () {
            setState(() => _manualMode = true);
          },
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
          ],
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
