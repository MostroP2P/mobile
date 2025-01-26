import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mostro_mobile/app/app_theme.dart';

class CurrencyTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;

  /// If a single integer is entered, do we treat min and max as the same number (true)
  /// or do we treat max as null (false)?
  final bool singleValueSetsMaxSameAsMin;

  const CurrencyTextField({
    super.key,
    required this.controller,
    required this.label,
    this.singleValueSetsMaxSameAsMin = false,
  });

  @override
  State<CurrencyTextField> createState() => CurrencyTextFieldState();
}

class CurrencyTextFieldState extends State<CurrencyTextField> {
  /// This method does a final parse of the user input.
  /// Returns (minVal, maxVal) as int? (they can be null if invalid).
  (int?, int?) _parseInput() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return (null, null);

    // If there's a dash, we expect two integers
    if (text.contains('-')) {
      final parts = text.split('-');
      if (parts.length == 2) {
        final minStr = parts[0].trim();
        final maxStr = parts[1].trim();

        // both must be non-empty and parse to int
        if (minStr.isEmpty || maxStr.isEmpty) {
          return (null, null);
        }
        final minVal = int.tryParse(minStr);
        final maxVal = int.tryParse(maxStr);
        return (minVal, maxVal);
      } else {
        // e.g. "10-20-30" => invalid
        return (null, null);
      }
    } else {
      // Single integer
      final singleVal = int.tryParse(text);
      if (singleVal != null) {
        if (widget.singleValueSetsMaxSameAsMin) {
          return (singleVal, singleVal);
        } else {
          return (singleVal, null);
        }
      }
      return (null, null);
    }
  }

  /// Public getters
  int? get minAmount => _parseInput().$1;
  int? get maxAmount => _parseInput().$2;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.dark1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextFormField(
        controller: widget.controller,
        keyboardType: TextInputType.number,
        // The input formatter allows partial states like "10-" or just "-"
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^[0-9]*-?[0-9]*$')),
        ],
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: widget.label,
          labelStyle: const TextStyle(color: Colors.grey),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter a value';
          }
          final (minVal, maxVal) = _parseInput();
          if (minVal == null && maxVal == null) {
            return 'Invalid number or range';
          }
          // If we want to ensure min <= max, we can do:
          if (minVal != null && maxVal != null && minVal > maxVal) {
            return 'Minimum cannot exceed maximum';
          }
          return null;
        },
      ),
    );
  }
}
