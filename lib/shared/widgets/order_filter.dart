import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/home/providers/home_order_providers.dart';
import 'package:mostro_mobile/features/order/providers/payment_methods_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';

/// A custom multi-select field based on Autocomplete.
/// It lets the user type to filter options and add selections which are shown as Chips.
class MultiSelectAutocomplete extends StatefulWidget {
  final String label;
  final List<String> options;
  final List<String> selectedValues;
  final ValueChanged<List<String>> onChanged;

  const MultiSelectAutocomplete({
    super.key,
    required this.label,
    required this.options,
    required this.selectedValues,
    required this.onChanged,
  });

  @override
  MultiSelectAutocompleteState createState() => MultiSelectAutocompleteState();
}

class MultiSelectAutocompleteState extends State<MultiSelectAutocomplete> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    //_controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            return widget.options.where((option) =>
                option
                    .toLowerCase()
                    .contains(textEditingValue.text.toLowerCase()) &&
                !widget.selectedValues.contains(option));
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: AppTheme.backgroundCard,
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(4),
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelected(option),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 1),
                          child: Text(
                            option,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          onSelected: (String selection) {
            final updated = List<String>.from(widget.selectedValues)
              ..add(selection);
            widget.onChanged(updated);
            _controller.clear();
          },
          fieldViewBuilder:
              (context, textEditingController, focusNode, onFieldSubmitted) {
            _controller = textEditingController;
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.backgroundInput,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppTheme.textSecondary,
                    width: 1.5,
                  ),
                ),
                hintText: S.of(context)!.typeToAdd,
                hintStyle: TextStyle(
                  color: AppTheme.textInactive,
                  fontSize: 14,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: widget.selectedValues.isEmpty
              ? [
                  Text(
                    S.of(context)!.noneSelected,
                    style: TextStyle(
                      color: AppTheme.textInactive,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                ]
              : widget.selectedValues
                  .map((value) => Container(
                        margin: const EdgeInsets.only(right: 6, bottom: 4),
                        child: Material(
                          color: AppTheme.backgroundInput,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundInput,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.textSecondary.withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  value,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    final updated = List<String>.from(widget.selectedValues)
                                      ..remove(value);
                                    widget.onChanged(updated);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.textSecondary.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ))
                  .toList(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// The updated OrderFilter widget which uses the MultiSelectAutocomplete widgets and a slider.
class OrderFilter extends ConsumerStatefulWidget {
  const OrderFilter({super.key});

  @override
  ConsumerState<OrderFilter> createState() => OrderFilterState();
}

class OrderFilterState extends ConsumerState<OrderFilter> {
  List<String> selectedFiatCurrencies = [];
  List<String> selectedPaymentMethods = [];
  double ratingMin = 0.0;
  double ratingMax = 5.0;
  double premiumMin = -10.0;
  double premiumMax = 10.0;

  // Options for the multi-select fields.
  
  List<String> _getAllPaymentMethods(Map<String, dynamic> paymentMethodsData) {
    final Set<String> allMethods = {};
    
    // Add all payment methods from all currencies
    for (final methods in paymentMethodsData.values) {
      if (methods is List) {
        allMethods.addAll(methods.cast<String>());
      }
    }
    
    // Remove "Other" since it's for custom input, not filtering
    allMethods.remove('Other');
    
    final sortedMethods = allMethods.toList()..sort();
    return sortedMethods;
  }

  @override
  void initState() {
    super.initState();
    // Load current filter values from providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      final currencies = ref.read(currencyFilterProvider);
      final paymentMethods = ref.read(paymentMethodFilterProvider);
      final currentRatingRange = ref.read(ratingFilterProvider);
      final currentPremiumRange = ref.read(premiumRangeFilterProvider);
      
      setState(() {
        selectedFiatCurrencies = List.from(currencies);
        selectedPaymentMethods = List.from(paymentMethods);
        final (min: rMin, max: rMax) = currentRatingRange;
        ratingMin = rMin;
        ratingMax = rMax;
        premiumMin = currentPremiumRange.min;
        premiumMax = currentPremiumRange.max;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final currenciesAsync = ref.watch(currencyCodesProvider);
    final paymentMethodsAsync = ref.watch(paymentMethodsDataProvider);
    
    return Container(
      width: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with title and close button.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const HeroIcon(HeroIcons.funnel,
                      style: HeroIconStyle.outline, color: AppTheme.mostroGreen),
                  const SizedBox(width: 8),
                  Text(
                    S.of(context)!.filter.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 22),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Fiat currencies using Autocomplete multi-select.
          currenciesAsync.when(
            data: (currencies) => MultiSelectAutocomplete(
              label: S.of(context)!.fiatCurrencies,
              options: currencies.keys.toList()..sort(),
              selectedValues: selectedFiatCurrencies,
              onChanged: (values) {
                setState(() {
                  selectedFiatCurrencies = values;
                });
              },
            ),
            loading: () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.fiatCurrencies,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundInput,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      S.of(context)!.loadingCurrencies,
                      style: const TextStyle(
                        color: AppTheme.textInactive,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
            error: (error, stack) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.fiatCurrencies,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                MultiSelectAutocomplete(
                  label: S.of(context)!.fiatCurrencies,
                  options: ['USD', 'EUR', 'VES'], // Fallback options
                  selectedValues: selectedFiatCurrencies,
                  onChanged: (values) {
                    setState(() {
                      selectedFiatCurrencies = values;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Payment methods using Autocomplete multi-select.
          paymentMethodsAsync.when(
            data: (paymentMethodsData) => MultiSelectAutocomplete(
              label: S.of(context)!.paymentMethods,
              options: _getAllPaymentMethods(paymentMethodsData),
              selectedValues: selectedPaymentMethods,
              onChanged: (values) {
                setState(() {
                  selectedPaymentMethods = values;
                });
              },
            ),
            loading: () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.paymentMethods,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundInput,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      S.of(context)!.loadingPaymentMethods,
                      style: const TextStyle(
                        color: AppTheme.textInactive,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
            error: (error, stack) => MultiSelectAutocomplete(
              label: S.of(context)!.paymentMethods,
              options: ['Bank Transfer', 'Cash in person', 'PayPal', 'Zelle'], // Fallback options
              selectedValues: selectedPaymentMethods,
              onChanged: (values) {
                setState(() {
                  selectedPaymentMethods = values;
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          // Premium/Discount range filter
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.of(context)!.premiumRange,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    "${S.of(context)!.discount}: ${premiumMin.toInt()}%",
                    style: const TextStyle(
                      color: AppTheme.sellColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "${S.of(context)!.premium}: ${premiumMax.toInt()}%",
                    style: const TextStyle(
                      color: AppTheme.buyColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppTheme.textSecondary,
                  inactiveTrackColor: AppTheme.backgroundInput,
                  thumbColor: AppTheme.textSecondary,
                  overlayColor: AppTheme.textSecondary.withValues(alpha: 0.2),
                  valueIndicatorColor: AppTheme.textSecondary,
                  valueIndicatorTextStyle: const TextStyle(
                    color: AppTheme.backgroundDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                ),
                child: RangeSlider(
                  values: RangeValues(premiumMin, premiumMax),
                  min: -10.0,
                  max: 10.0,
                  divisions: 20,
                  labels: RangeLabels(
                    "${premiumMin.toInt()}%",
                    "${premiumMax.toInt()}%"
                  ),
                  onChanged: (values) {
                    setState(() {
                      premiumMin = values.start;
                      premiumMax = values.end;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Rating range slider between 0 and 5.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.of(context)!.reputation,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    "${S.of(context)!.min}: ${ratingMin.toInt()}",
                    style: const TextStyle(
                      color: AppTheme.sellColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "${S.of(context)!.max}: ${ratingMax.toInt()}",
                    style: const TextStyle(
                      color: AppTheme.buyColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppTheme.textSecondary,
                  inactiveTrackColor: AppTheme.backgroundInput,
                  thumbColor: AppTheme.textSecondary,
                  overlayColor: AppTheme.textSecondary.withValues(alpha: 0.2),
                  valueIndicatorColor: AppTheme.textSecondary,
                  valueIndicatorTextStyle: const TextStyle(
                    color: AppTheme.backgroundDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                ),
                child: RangeSlider(
                  values: RangeValues(ratingMin, ratingMax),
                  min: 0.0,
                  max: 5.0,
                  divisions: 5,
                  labels: RangeLabels(
                    ratingMin.toInt().toString(),
                    ratingMax.toInt().toString()
                  ),
                  onChanged: (values) {
                    setState(() {
                      ratingMin = values.start;
                      ratingMax = values.end;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Apply and Clear buttons
          Row(
            children: [
              Flexible(
                flex: 1,
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      // Clear all filters
                      setState(() {
                        selectedFiatCurrencies.clear();
                        selectedPaymentMethods.clear();
                        ratingMin = 0.0;
                        ratingMax = 5.0;
                        premiumMin = -10.0;
                        premiumMax = 10.0;
                      });
                      
                      ref.read(currencyFilterProvider.notifier).state = [];
                      ref.read(paymentMethodFilterProvider.notifier).state = [];
                      ref.read(ratingFilterProvider.notifier).state = (min: 0.0, max: 5.0);
                      ref.read(premiumRangeFilterProvider.notifier).state = (min: -10.0, max: 10.0);
                      
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: BorderSide(
                        color: AppTheme.textSecondary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      S.of(context)!.clear.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                flex: 1,
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      // Apply filters to providers
                      ref.read(currencyFilterProvider.notifier).state = selectedFiatCurrencies;
                      ref.read(paymentMethodFilterProvider.notifier).state = selectedPaymentMethods;
                      ref.read(ratingFilterProvider.notifier).state = (min: ratingMin, max: ratingMax);
                      ref.read(premiumRangeFilterProvider.notifier).state = (min: premiumMin, max: premiumMax);
                      
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.mostroGreen,
                      foregroundColor: AppTheme.backgroundDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ),
                    child: Text(
                      S.of(context)!.apply.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
