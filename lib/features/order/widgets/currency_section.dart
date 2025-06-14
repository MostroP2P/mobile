import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/features/order/widgets/form_section.dart';
import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';

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
          ? 'Select the fiat currency you will pay with'
          : 'Select the Fiat Currency you want to receive',
      icon: const Text('\$',
          style: TextStyle(color: Color(0xFF8CC63F), fontSize: 18)),
      iconBackgroundColor: const Color(0xFF764BA2).withValues(alpha: 0.3),
      child: currenciesAsync.when(
        loading: () => const Text('Loading currencies...',
            style: TextStyle(color: Colors.white)),
        error: (_, __) => const Text('Error loading currencies',
            style: TextStyle(color: Colors.red)),
        data: (currencies) {
          final currency = currencies[selectedFiatCode];
          String flag = '🏳️';
          String name = 'US Dollar';

          if (currency != null) {
            flag = currency.emoji;
            name = currency.name;
          }

          return InkWell(
            key: const Key('fiatCodeDropdown'),
            onTap: () {
              _showCurrencySelectionDialog(context, ref, onCurrencySelected);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  key: Key('currency_$selectedFiatCode'),
                  children: [
                    Text(flag, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      '$selectedFiatCode - $name',
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

  void _showCurrencySelectionDialog(BuildContext context, WidgetRef ref, VoidCallback onCurrencySelected) {
    // State for search query
    String searchQuery = '';
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: const Color(0xFF1E2230),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    backgroundColor: const Color(0xFF252a3a),
                    title: const Text('Select Currency',
                        style: TextStyle(color: Colors.white)),
                    leading: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    centerTitle: true,
                    elevation: 0,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF252a3a),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF8CC63F).withOpacity(0.3), width: 1),
                      ),
                      child: TextField(
                        textAlign: TextAlign.left,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search currencies...',
                          hintStyle: const TextStyle(color: Colors.grey),
                          prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                          filled: false,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
                        ),
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value.toLowerCase();
                          });
                        },
                      ),
                    ),
                  ),
                  Flexible(
                    child: Consumer(
                      builder: (context, ref, child) {
                        final currenciesAsync = ref.watch(currencyCodesProvider);
                        return currenciesAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (_, __) => Center(
                            child: Text(
                              'Error loading currencies',
                              style: TextStyle(color: Colors.red.shade300),
                            ),
                          ),
                          data: (currencies) {
                            final selectedCode = ref.watch(selectedFiatCodeProvider);
                            final filteredCurrencies = currencies.entries
                                .where((entry) {
                                  final code = entry.key.toLowerCase();
                                  final name = entry.value.name.toLowerCase();
                                  return searchQuery.isEmpty ||
                                      code.contains(searchQuery) ||
                                      name.contains(searchQuery);
                                })
                                .toList()
                                  ..sort((a, b) => a.key.compareTo(b.key));

                            return filteredCurrencies.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Text(
                                        'No currencies found',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: filteredCurrencies.length,
                                    itemBuilder: (context, index) {
                                      final entry = filteredCurrencies[index];
                                      final code = entry.key;
                                      final currency = entry.value;
                                      final isSelected = code == selectedCode;

                                      return ListTile(
  key: Key('currency_$code'),
                                        leading: Text(
                                          currency.emoji.isNotEmpty
                                              ? currency.emoji
                                              : '🏳️',
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                        title: Text(
                                          '$code - ${currency.name}',
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                        trailing: isSelected
                                            ? const Icon(Icons.check,
                                                color: Color(0xFF8CC63F))
                                            : null,
                                        onTap: () {
                                          ref
                                              .read(selectedFiatCodeProvider.notifier)
                                              .state = code;
                                          onCurrencySelected();
                                          Navigator.of(context).pop();
                                        },
                                      );
                                    },
                                  );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
