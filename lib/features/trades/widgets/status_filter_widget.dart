import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/features/trades/providers/trades_provider.dart';

class StatusFilterWidget extends ConsumerWidget {
  const StatusFilterWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedStatusFilter = ref.watch(statusFilterProvider);

    // Helper function to get display text for current selection
    String getDisplayText() {
      if (selectedStatusFilter == null) {
        return '${S.of(context)!.statusFilter} | ${S.of(context)!.allStatuses}';
      }

      switch (selectedStatusFilter) {
        case Status.pending:
          return '${S.of(context)!.statusFilter} | ${S.of(context)!.statusPending}';
        case Status.waitingPayment:
          return '${S.of(context)!.statusFilter} | ${S.of(context)!.statusWaitingPayment}';
        case Status.waitingBuyerInvoice:
          return '${S.of(context)!.statusFilter} | ${S.of(context)!.statusWaitingBuyerInvoice}';
        case Status.active:
          return '${S.of(context)!.statusFilter} | ${S.of(context)!.statusActive}';
        case Status.fiatSent:
          return '${S.of(context)!.statusFilter} | ${S.of(context)!.statusFiatSent}';
        case Status.success:
          return '${S.of(context)!.statusFilter} | ${S.of(context)!.statusSuccess}';
        case Status.canceled:
          return '${S.of(context)!.statusFilter} | ${S.of(context)!.statusCanceled}';
        case Status.settledHoldInvoice:
          return '${S.of(context)!.statusFilter} | ${S.of(context)!.statusSettledHoldInvoice}';
        default:
          return S.of(context)!.statusFilter;
      }
    }

    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.backgroundDark,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24),
        ),
        child: PopupMenuButton<String>(
          color: AppTheme.backgroundDark,
          offset: const Offset(0, 40),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.filter,
                color: Colors.white70,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                getDisplayText(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'ALL',
              child: Text(
                S.of(context)!.allStatuses,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
            PopupMenuItem<String>(
              value: 'pending',
              child: Text(
                S.of(context)!.statusPending,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
            PopupMenuItem<String>(
              value: 'waitingPayment',
              child: Text(
                S.of(context)!.statusWaitingPayment,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
            PopupMenuItem<String>(
              value: 'waitingBuyerInvoice',
              child: Text(
                S.of(context)!.statusWaitingBuyerInvoice,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
            PopupMenuItem<String>(
              value: 'active',
              child: Text(
                S.of(context)!.statusActive,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
            PopupMenuItem<String>(
              value: 'fiatSent',
              child: Text(
                S.of(context)!.statusFiatSent,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
            PopupMenuItem<String>(
              value: 'success',
              child: Text(
                S.of(context)!.statusSuccess,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
            PopupMenuItem<String>(
              value: 'canceled',
              child: Text(
                S.of(context)!.statusCanceled,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
            PopupMenuItem<String>(
              value: 'settledHoldInvoice',
              child: Text(
                S.of(context)!.statusSettledHoldInvoice,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          onSelected: (String value) {
            Status? statusValue;
            switch (value) {
              case 'ALL':
                statusValue = null;
                break;
              case 'pending':
                statusValue = Status.pending;
                break;
              case 'waitingPayment':
                statusValue = Status.waitingPayment;
                break;
              case 'waitingBuyerInvoice':
                statusValue = Status.waitingBuyerInvoice;
                break;
              case 'active':
                statusValue = Status.active;
                break;
              case 'fiatSent':
                statusValue = Status.fiatSent;
                break;
              case 'success':
                statusValue = Status.success;
                break;
              case 'canceled':
                statusValue = Status.canceled;
                break;
              case 'settledHoldInvoice':
                statusValue = Status.settledHoldInvoice;
                break;
            }
            ref.read(statusFilterProvider.notifier).state = statusValue;
          },
        ),
      ),
    );
  }
}
