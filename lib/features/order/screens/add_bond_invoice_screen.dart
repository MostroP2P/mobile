import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/bond_payout_request.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/features/wallet/providers/nwc_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/shared/utils/snack_bar_helper.dart';
import 'package:mostro_mobile/shared/widgets/nwc_invoice_widget.dart';

class AddBondInvoiceScreen extends ConsumerStatefulWidget {
  final String orderId;

  const AddBondInvoiceScreen({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<AddBondInvoiceScreen> createState() =>
      _AddBondInvoiceScreenState();
}

class _AddBondInvoiceScreenState extends ConsumerState<AddBondInvoiceScreen> {
  final TextEditingController _invoiceController = TextEditingController();
  bool _manualMode = false;

  @override
  void dispose() {
    _invoiceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderId = widget.orderId;
    final mostroOrderAsync =
        ref.watch(mostroBondPayoutRequestStreamProvider(orderId));

    return mostroOrderAsync.when(
      data: (mostroMessage) {
        final payload = mostroMessage?.getPayload<BondPayoutRequest>();
        final amount = payload?.order.amount ?? 0;
        final orderIdValue = payload?.order.id ?? orderId;

        // slashed_at arrives as Unix seconds in the BondPayoutRequest
        // payload (mostro-core 0.11.3+). Convert to milliseconds for
        // DateTime.
        final slashedAtMs =
            payload != null ? payload.slashedAt * 1000 : null;
        final infoEvent =
            ref.watch(orderRepositoryProvider).mostroInstance;
        final claimWindowDays = infoEvent == null
            ? null
            : MostroInstance.fromEvent(infoEvent).bondPayoutClaimWindowDays;
        final deadline = (slashedAtMs != null && claimWindowDays != null)
            ? DateTime.fromMillisecondsSinceEpoch(slashedAtMs)
                .add(Duration(days: claimWindowDays))
            : null;

        final nwcState = ref.watch(nwcProvider);
        final showNwc = nwcState.status == NwcStatus.connected &&
            !_manualMode &&
            amount > 0;

        return Scaffold(
          backgroundColor: AppTheme.dark1,
          appBar: OrderAppBar(title: S.of(context)!.addBondInvoiceTitle),
          body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(context).viewPadding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildExplanation(
                  amount: amount,
                  orderIdValue: orderIdValue,
                  deadline: deadline,
                ),
                const SizedBox(height: 24),
                if (showNwc)
                  NwcInvoiceWidget(
                    sats: amount,
                    orderId: orderId,
                    onInvoiceConfirmed: (invoice) async {
                      await _submit(invoice, amount);
                    },
                    onFallbackToManual: () {
                      setState(() => _manualMode = true);
                    },
                  )
                else
                  _buildManualEntry(amount),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildExplanation({
    required int amount,
    required String orderIdValue,
    required DateTime? deadline,
  }) {
    final s = S.of(context)!;
    final deadlineLine =
        deadline == null ? null : s.addBondInvoiceDeadline(_formatDate(deadline));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.addBondInvoiceWonLine(orderIdValue),
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          s.addBondInvoiceSubmitLine(amount),
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
          ),
        ),
        if (deadlineLine != null) ...[
          const SizedBox(height: 8),
          Text(
            deadlineLine,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildManualEntry(int amount) {
    final s = S.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.backgroundInput,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextFormField(
            key: const Key('bondInvoiceTextField'),
            controller: _invoiceController,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: s.addBondInvoiceInputLabel,
              labelStyle: const TextStyle(color: AppTheme.textSecondary),
              hintText: s.addBondInvoiceInputHint,
              hintStyle: const TextStyle(color: AppTheme.textSecondary),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              alignLabelWithHint: true,
            ),
            maxLines: 6,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                key: const Key('submitBondInvoiceButton'),
                onPressed: () async {
                  final invoice = _invoiceController.text.trim();
                  if (invoice.isNotEmpty) {
                    await _submit(invoice, amount);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.activeColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
                child: Text(
                  s.addBondInvoiceSubmitButton,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _submit(String invoice, int amount) async {
    final orderNotifier =
        ref.read(orderNotifierProvider(widget.orderId).notifier);
    try {
      logger.d('Submitting bond payout invoice for order ${widget.orderId}');
      await orderNotifier.sendBondInvoice(widget.orderId, invoice, amount);
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          SnackBarHelper.showTopSnackBar(
            context,
            S.of(context)!.addBondInvoiceFailedToSubmit(e.toString()),
          );
        });
      }
    }
  }

  String _formatDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd $hh:$mi';
  }
}
