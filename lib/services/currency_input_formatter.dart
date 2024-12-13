import 'package:flutter/services.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final regex = RegExp(r'^\d*\.?\d{0,2}$');

    if (regex.hasMatch(text)) {
      return newValue;
    } else {
      return oldValue;
    }
  }
}
