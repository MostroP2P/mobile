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

    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.backgroundDark,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<Status?>(
            value: selectedStatusFilter,
            isDense: true,
            hint: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.filter,
                  color: Colors.white70,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  S.of(context)!.statusFilter,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            selectedItemBuilder: (BuildContext context) {
              return [
                null, // All
                Status.pending,
                Status.waitingPayment,
                Status.waitingBuyerInvoice,
                Status.active,
                Status.fiatSent,
                Status.success,
                Status.canceled,
                Status.settledHoldInvoice,
              ].map<Widget>((Status? value) {
                String displayText = S.of(context)!.statusFilter;
                if (value != null) {
                  switch (value) {
                    case Status.pending:
                      displayText += ' | ${S.of(context)!.statusPending}';
                      break;
                    case Status.waitingPayment:
                      displayText +=
                          ' | ${S.of(context)!.statusWaitingPayment}';
                      break;
                    case Status.waitingBuyerInvoice:
                      displayText +=
                          ' | ${S.of(context)!.statusWaitingBuyerInvoice}';
                      break;
                    case Status.active:
                      displayText += ' | ${S.of(context)!.statusActive}';
                      break;
                    case Status.fiatSent:
                      displayText += ' | ${S.of(context)!.statusFiatSent}';
                      break;
                    case Status.success:
                      displayText += ' | ${S.of(context)!.statusSuccess}';
                      break;
                    case Status.canceled:
                      displayText += ' | ${S.of(context)!.statusCanceled}';
                      break;
                    case Status.settledHoldInvoice:
                      displayText +=
                          ' | ${S.of(context)!.statusSettledHoldInvoice}';
                      break;
                    default:
                      break;
                  }
                }
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.filter,
                      color: Colors.white70,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      displayText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
            dropdownColor: AppTheme.backgroundDark,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
            items: [
              DropdownMenuItem<Status?>(
                value: null,
                child: Text(S.of(context)!.allStatuses),
              ),
              DropdownMenuItem<Status?>(
                value: Status.pending,
                child: Text(S.of(context)!.statusPending),
              ),
              DropdownMenuItem<Status?>(
                value: Status.waitingPayment,
                child: Text(S.of(context)!.statusWaitingPayment),
              ),
              DropdownMenuItem<Status?>(
                value: Status.waitingBuyerInvoice,
                child: Text(S.of(context)!.statusWaitingBuyerInvoice),
              ),
              DropdownMenuItem<Status?>(
                value: Status.active,
                child: Text(S.of(context)!.statusActive),
              ),
              DropdownMenuItem<Status?>(
                value: Status.fiatSent,
                child: Text(S.of(context)!.statusFiatSent),
              ),
              DropdownMenuItem<Status?>(
                value: Status.success,
                child: Text(S.of(context)!.statusSuccess),
              ),
              DropdownMenuItem<Status?>(
                value: Status.canceled,
                child: Text(S.of(context)!.statusCanceled),
              ),
              DropdownMenuItem<Status?>(
                value: Status.settledHoldInvoice,
                child: Text(S.of(context)!.statusSettledHoldInvoice),
              ),
            ],
            onChanged: (Status? newValue) {
              ref.read(statusFilterProvider.notifier).state = newValue;
            },
          ),
        ),
      ),
    );
  }
}
