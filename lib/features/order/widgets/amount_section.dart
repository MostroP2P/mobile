import 'package:flutter/material.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/features/order/widgets/form_section.dart';
import 'package:mostro_mobile/generated/l10n.dart';

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
          ? S.of(context)!.enterFiatAmountBuy
          : S.of(context)!.enterFiatAmountSell,
      icon: const Icon(Icons.credit_card, color: Color(0xFF8CC63F), size: 18),
      iconBackgroundColor: const Color(0xFF8CC63F).withValues(alpha: 0.3),
      child: TextFormField(
        key: const Key('fiatAmountField'),
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: S.of(context)!.enterAmountHint,
          hintStyle: const TextStyle(color: Colors.grey),
        ),
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        onChanged: onAmountChanged,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return S.of(context)!.pleaseEnterAmount;
          }
          
          // Regex to match either a single number or a range format (number-number)
          // The regex allows optional spaces around the hyphen
          final regex = RegExp(r'^\d+$|^\d+\s*-\s*\d+$');
          
          if (!regex.hasMatch(value)) {
            return S.of(context)!.pleaseEnterValidAmount;
          }
          
          // If it's a range, check that the first number is less than the second
          if (value.contains('-')) {
            final parts = value.split('-');
            final firstNum = int.tryParse(parts[0].trim());
            final secondNum = int.tryParse(parts[1].trim());
            
            if (firstNum != null && secondNum != null && firstNum >= secondNum) {
              return S.of(context)!.rangeFirstLowerThanSecond;
            }
          }
          
          return null;
        },
      ),
    );
  }
}
