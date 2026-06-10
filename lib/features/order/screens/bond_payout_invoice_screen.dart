import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/widgets/order_app_bar.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/shared/providers.dart';
import 'package:mostro_mobile/shared/utils/bond_payout_helpers.dart';
import 'package:mostro_mobile/shared/utils/snack_bar_helper.dart';

class BondPayoutInvoiceScreen extends ConsumerStatefulWidget {
  final String orderId;

  const BondPayoutInvoiceScreen({super.key, required this.orderId});

  @override
  ConsumerState<BondPayoutInvoiceScreen> createState() =>
      _BondPayoutInvoiceScreenState();
}

class _BondPayoutInvoiceScreenState
    extends ConsumerState<BondPayoutInvoiceScreen> {
  final TextEditingController _invoiceController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _invoiceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final historyAsync =
        ref.watch(mostroMessageHistoryProvider(widget.orderId));

    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: OrderAppBar(title: s.addBondInvoiceTitle),
      body: historyAsync.when(
        data: (messages) {
          final phase = bondPayoutPhase(messages);

          if (phase == BondPayoutPhase.acknowledged) {
            return _buildInfoBody(
              s: s,
              message: s.bondInvoiceAcceptedMessage,
            );
          }
          if (phase == BondPayoutPhase.completed) {
            return _buildInfoBody(
              s: s,
              message: s.bondPayoutCompletedMessage,
            );
          }

          final request = latestBondPayoutRequest(messages);
          if (request == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  s.addBondInvoiceMessage,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final instance =
              ref.watch(orderRepositoryProvider).mostroInstance;
          final claimWindowDays = instance?.bondPayoutClaimWindowDays ?? 15;
          if (isBondClaimExpired(request.slashedAt, claimWindowDays)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) context.go('/');
            });
            return const SizedBox.shrink();
          }

          final deadline =
              bondClaimDeadline(request.slashedAt, claimWindowDays);
          final formattedDeadline =
              DateFormat.yMMMd().add_jm().format(deadline);

          return _buildBody(
            s: s,
            request: request,
            formattedDeadline: formattedDeadline,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) {
          logger.e(
            'Failed to load bond payout history for ${widget.orderId}',
            error: e,
            stackTrace: stack,
          );
          return Center(
            child: Text(
              s.errorLoadingBondPayout,
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody({
    required S s,
    required BondPayoutRequest request,
    required String formattedDeadline,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.addBondInvoiceSubmitLine(request.order.amount.toString()),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            s.addBondInvoiceWonLine(request.order.id ?? widget.orderId),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s.addBondInvoiceDeadline(formattedDeadline),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.backgroundInput,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: TextFormField(
              key: const Key('bondPayoutInvoiceTextField'),
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
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('bondPayoutSubmitButton'),
              onPressed: _submitting ? null : _onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.activeColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Text(
                      s.addBondInvoiceSubmitButton,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBody({required S s, required String message}) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('bondPayoutCloseButton'),
              onPressed: () => context.go('/'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.activeColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                s.bondPayoutCloseButton,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onSubmit() async {
    final invoice = _invoiceController.text.trim();
    if (invoice.isEmpty) return;

    setState(() => _submitting = true);
    final notifier =
        ref.read(orderNotifierProvider(widget.orderId).notifier);
    try {
      await notifier.sendBondPayoutInvoice(invoice);
      if (mounted) context.go('/');
    } catch (e, stack) {
      logger.e(
        'Failed to submit bond payout invoice for ${widget.orderId}',
        error: e,
        stackTrace: stack,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      final s = S.of(context)!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          SnackBarHelper.showTopSnackBar(
            context,
            s.addBondInvoiceFailedToSubmit,
          );
        }
      });
    }
  }
}
