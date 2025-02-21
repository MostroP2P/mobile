import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';

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
  MultiSelectAutocompleteState createState() =>
      MultiSelectAutocompleteState();
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
          style: const TextStyle(color: AppTheme.mostroGreen),
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
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Type to add...',
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: widget.selectedValues.isEmpty
              ? [
                  const Text(
                    'None selected',
                    style: TextStyle(color: AppTheme.cream1),
                  )
                ]
              : widget.selectedValues
                  .map((value) => Chip(
                        label: Text(value),
                        onDeleted: () {
                          final updated = List<String>.from(widget.selectedValues)
                            ..remove(value);
                          widget.onChanged(updated);
                        },
                      ))
                  .toList(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// The updated OrderFilter widget which uses the MultiSelectAutocomplete widgets and a slider.
class OrderFilter extends StatefulWidget {
  const OrderFilter({super.key});

  @override
  OrderFilterState createState() => OrderFilterState();
}

class OrderFilterState extends State<OrderFilter> {
  List<String> selectedFiatCurrencies = [];
  List<String> selectedPaymentMethods = [];
  double rating = 0.0;

  // Options for the multi-select fields.
  final List<String> fiatOptions = ['USD', 'EUR', 'VES'];
  final List<String> paymentMethodsOptions = [
    'face to face',
    'bank transfer',
    'lightning'
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cream1,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .1),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
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
                children: const [
                  HeroIcon(HeroIcons.funnel,
                      style: HeroIconStyle.outline, color: AppTheme.dark2),
                  SizedBox(width: 8),
                  Text(
                    'FILTER',
                    style: TextStyle(
                      color: AppTheme.dark2,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon:
                    const Icon(Icons.close, color: AppTheme.dark2, size: 20),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Fiat currencies using Autocomplete multi-select.
          MultiSelectAutocomplete(
            label: 'Fiat currencies',
            options: fiatOptions,
            selectedValues: selectedFiatCurrencies,
            onChanged: (values) {
              setState(() {
                selectedFiatCurrencies = values;
              });
            },
          ),
          const SizedBox(height: 12),
          // Payment methods using Autocomplete multi-select.
          MultiSelectAutocomplete(
            label: 'Payment methods',
            options: paymentMethodsOptions,
            selectedValues: selectedPaymentMethods,
            onChanged: (values) {
              setState(() {
                selectedPaymentMethods = values;
              });
            },
          ),
          const SizedBox(height: 12),
          // Rating slider between 0 and 5.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Rating: ${rating.toStringAsFixed(1)}",
                style: const TextStyle(color: AppTheme.mostroGreen),
              ),
              Slider(
                value: rating,
                min: 0,
                max: 5,
                divisions: 5,
                label: rating.toStringAsFixed(1),
                onChanged: (val) {
                  setState(() {
                    rating = val;
                  });
                },
              )
            ],
          ),
        ],
      ),
    );
  }
}
