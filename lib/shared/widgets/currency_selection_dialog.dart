import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class CurrencySelectionDialog {
  /// Shows a currency selection dialog and returns the selected currency code
  /// Returns null if the user cancels the dialog
  static Future<String?> show(
    BuildContext context,
    WidgetRef ref, {
    String? title,
    String? currentSelection,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) => _CurrencySelectionDialogWidget(
        title: title ?? S.of(context)!.selectCurrency,
        currentSelection: currentSelection,
      ),
    );
  }
}

class _CurrencySelectionDialogWidget extends ConsumerStatefulWidget {
  final String title;
  final String? currentSelection;

  const _CurrencySelectionDialogWidget({
    required this.title,
    this.currentSelection,
  });

  @override
  ConsumerState<_CurrencySelectionDialogWidget> createState() =>
      _CurrencySelectionDialogWidgetState();
}

class _CurrencySelectionDialogWidgetState
    extends ConsumerState<_CurrencySelectionDialogWidget> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E2230),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            backgroundColor: const Color(0xFF252a3a),
            title: Text(
              widget.title,
              style: const TextStyle(color: Colors.white),
            ),
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
                border: Border.all(
                  color: AppTheme.mostroGreen.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: TextField(
                textAlign: TextAlign.left,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: S.of(context)!.searchCurrencies,
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.grey, size: 20),
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
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => Center(
                    child: Text(
                      S.of(context)!.errorLoadingCurrencies,
                      style: TextStyle(color: Colors.red.shade300),
                    ),
                  ),
                  data: (currencies) {
                    final filteredCurrencies =
                        currencies.entries.where((entry) {
                      final code = entry.key.toLowerCase();
                      final name = entry.value.name.toLowerCase();
                      return searchQuery.isEmpty ||
                          code.contains(searchQuery) ||
                          name.contains(searchQuery);
                    }).toList()
                          ..sort((a, b) => a.key.compareTo(b.key));

                    return filteredCurrencies.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                S.of(context)!.noCurrenciesFound,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredCurrencies.length,
                            itemBuilder: (context, index) {
                              final entry = filteredCurrencies[index];
                              final code = entry.key;
                              final currency = entry.value;
                              final isSelected =
                                  code == widget.currentSelection;

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
                                        color: AppTheme.mostroGreen)
                                    : null,
                                onTap: () {
                                  Navigator.of(context).pop(code);
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
  }
}
