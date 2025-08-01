import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/features/order/widgets/form_section.dart';
import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';
import 'package:mostro_mobile/shared/widgets/currency_selection_dialog.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class CurrencySection extends ConsumerWidget {
  final OrderType orderType;
  final VoidCallback onCurrencySelected;

  const CurrencySection(
      {super.key, required this.orderType, required this.onCurrencySelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFiatCode = ref.watch(selectedFiatCodeProvider);
    final currenciesAsync = ref.watch(currencyCodesProvider);

    return FormSection(
      title: orderType == OrderType.buy
          ? S.of(context)!.selectFiatCurrencyPay
          : S.of(context)!.selectFiatCurrencyReceive,
      icon: const Text('\$',
          style: TextStyle(color: Color(0xFF8CC63F), fontSize: 18)),
      iconBackgroundColor: const Color(0xFF764BA2).withValues(alpha: 0.3),
      child: currenciesAsync.when(
        loading: () => Text(S.of(context)!.loadingCurrencies,
            style: const TextStyle(color: Colors.white)),
        error: (_, __) => Text(S.of(context)!.errorLoadingCurrencies,
            style: const TextStyle(color: Colors.red)),
        data: (currencies) {
          String flag = '🏳️';
          String name = S.of(context)!.selectCurrency;
          String displayCode = '';

          if (selectedFiatCode != null) {
            final currency = currencies[selectedFiatCode];
            if (currency != null) {
              flag = currency.emoji;
              name = currency.name;
              displayCode = selectedFiatCode;
            }
          }

          return InkWell(
            key: const Key('fiatCodeDropdown'),
            onTap: () async {
              final selectedCode = await CurrencySelectionDialog.show(
                context,
                ref,
                currentSelection: selectedFiatCode,
              );
              if (selectedCode != null) {
                ref.read(selectedFiatCodeProvider.notifier).state = selectedCode;
                onCurrencySelected();
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  key: Key('currency_${selectedFiatCode ?? 'none'}'),
                  children: [
                    Text(flag, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      displayCode.isNotEmpty ? '$displayCode - $name' : name,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              ],
            ),
          );
        },
      ),
    );
  }

}
