import 'package:flutter/material.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/features/order/widgets/form_section.dart';

class AmountSection extends StatelessWidget {
  final OrderType orderType;
  final TextEditingController controller;
  final Function(String) onAmountChanged;

  const AmountSection({
    super.key,
    required this.orderType,
    required this.controller,
    required this.onAmountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: orderType == OrderType.buy
          ? 'Enter the fiat amount you want to pay (you can set a range)'
          : 'Enter the fiat amount you want to receive (you can set a range)',
      icon: const Icon(Icons.credit_card, color: Color(0xFF8CC63F), size: 18),
      iconBackgroundColor: const Color(0xFF8CC63F).withOpacity(0.3),
      child: TextFormField(
        key: const Key('fiatAmountField'),
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Enter amount (example: 100 or 100-500)',
          hintStyle: TextStyle(color: Colors.grey),
        ),
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        onChanged: onAmountChanged,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter an amount';
          }
          
          // Regex to match either a single number or a range format (number-number)
          // The regex allows optional spaces around the hyphen
          final regex = RegExp(r'^\d+$|^\d+\s*-\s*\d+$');
          
          if (!regex.hasMatch(value)) {
            return 'Please enter a valid amount (e.g., 100) or range (e.g., 100-500)';
          }
          
          // If it's a range, check that the first number is less than the second
          if (value.contains('-')) {
            final parts = value.split('-');
            final firstNum = int.tryParse(parts[0].trim());
            final secondNum = int.tryParse(parts[1].trim());
            
            if (firstNum != null && secondNum != null && firstNum >= secondNum) {
              return 'In a range, the first number must be less than the second';
            }
          }
          
          return null;
        },
      ),
    );
  }
}
