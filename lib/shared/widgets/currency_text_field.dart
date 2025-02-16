import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mostro_mobile/core/app_theme.dart';

class CurrencyTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<(int?, int?)>? onChanged;

  /// If a single integer is entered, do we treat min and max as the same number (true)
  /// or do we treat max as null (false)?
  final bool singleValueSetsMaxSameAsMin;

  const CurrencyTextField({
    super.key,
    required this.controller,
    required this.label,
    this.singleValueSetsMaxSameAsMin = false,
    this.onChanged,
  });

  @override
  State<CurrencyTextField> createState() => CurrencyTextFieldState();
}

class CurrencyTextFieldState extends State<CurrencyTextField> {
  (int?, int?) _parseInput() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return (null, null);
    if (text.contains('-')) {
      final parts = text.split('-');
      if (parts.length == 2) {
        final minVal = int.tryParse(parts[0].trim());
        final maxVal = int.tryParse(parts[1].trim());
        return (minVal, maxVal);
      } else {
        return (null, null);
      }
    } else {
      final value = int.tryParse(text);
      return (value, widget.singleValueSetsMaxSameAsMin ? value : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      style: const TextStyle(color: AppTheme.cream1),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^[0-9]*-?[0-9]*$')),
      ],
      decoration: InputDecoration(
        border: InputBorder.none,
        labelText: widget.label,
        labelStyle: const TextStyle(color: AppTheme.grey2),
      ),
      onChanged: (value) {
        final parsed = _parseInput();
        if (widget.onChanged != null) widget.onChanged!(parsed);
      },
      validator: (value) {
        final (minVal, maxVal) = _parseInput();
        if (minVal == null && maxVal == null) {
          return 'Invalid number or range';
        }
        if (minVal != null && maxVal != null && minVal > maxVal) {
          return 'Minimum cannot exceed maximum';
        }
        return null;
      },
    );
  }
}
