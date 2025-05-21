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
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Enter amount (example: 100 or 100-500)',
          hintStyle: TextStyle(color: Colors.grey),
        ),
        keyboardType: TextInputType.text,
        onChanged: onAmountChanged,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter an amount';
          }
          return null;
        },
      ),
    );
  }
}
