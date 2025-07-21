import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class CurrencyComboBox extends ConsumerWidget {
  final String label;
  final ValueChanged<String>? onSelected;

  const CurrencyComboBox({
    super.key,
    required this.label,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyCodesAsync = ref.watch(currencyCodesProvider);
    final selectedFiatCode = ref.watch(selectedFiatCodeProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.dark1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: currencyCodesAsync.when(
        loading: () => const Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stackTrace) => Row(
          children: [
            Text(S.of(context)!.errorLoadingCurrencies),
            TextButton(
              onPressed: () => ref.refresh(currencyCodesProvider),
              child: Text(S.of(context)!.retry),
            ),
          ],
        ),
        data: (currencyCodes) {
          // Create a list of string labels like "🇺🇸 USD - United States Dollar"
          final entries = currencyCodes.entries
              .map((e) =>
                  '${e.value.emoji.isNotEmpty ? e.value.emoji : '🏳️'} ${e.key} - ${e.value.name}')
              .toList();

          return Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                // If user hasn’t typed anything, show all entries
                return entries;
              }
              final query = textEditingValue.text.toLowerCase();
              return entries.where(
                (item) => item.toLowerCase().contains(query),
              );
            },
            onSelected: (String selection) {
              // Extract the ISO code (the part after flag and space, before " - ")
              // Format is "🇺🇸 USD - United States Dollar"
              final parts = selection.split(' - ');
              if (parts.isNotEmpty) {
                // Get the first part "🇺🇸 USD" and extract just "USD"
                final codeWithFlag = parts.first.trim();
                final code = codeWithFlag
                    .split(' ')
                    .last; // Get the last part after splitting by space
                // Update Riverpod state
                ref.read(selectedFiatCodeProvider.notifier).state = code;
                // Notify parent via callback if provided
                onSelected?.call(code);
              }
            },
            fieldViewBuilder:
                (context, textEditingController, focusNode, onFieldSubmitted) {
              // Initialize the text field with the selected code
              // so it shows up when the user opens the screen
              final existingLabel = currencyCodes[selectedFiatCode];
              if (existingLabel != null) {
                final flag = existingLabel.emoji.isNotEmpty
                    ? existingLabel.emoji
                    : '🏳️';
                textEditingController.text =
                    '$flag $selectedFiatCode - ${existingLabel.name}';
              }

              return TextFormField(
                controller: textEditingController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  labelText: label,
                  labelStyle: const TextStyle(color: AppTheme.grey2),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                style: const TextStyle(color: AppTheme.cream1),
                onFieldSubmitted: (value) => onFieldSubmitted(),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: AppTheme.dark1,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(8),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return InkWell(
                          onTap: () => onSelected(option),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Text(
                              option,
                              style: const TextStyle(color: AppTheme.cream1),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
