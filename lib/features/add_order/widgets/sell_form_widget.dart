import 'package:bitcoin_icons/bitcoin_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mostro_mobile/app/app_theme.dart';
import 'package:mostro_mobile/shared/widgets/currency_dropdown.dart';
import 'package:mostro_mobile/shared/widgets/currency_text_field.dart';

class SellFormWidget extends HookConsumerWidget {
  const SellFormWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final fiatAmountController = useTextEditingController();
    final satsAmountController = useTextEditingController();
    final paymentMethodController = useTextEditingController();

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Make sure your order is below 20K sats',
              style: TextStyle(color: AppTheme.grey2)),
          const SizedBox(height: 16),
          CurrencyDropdown(label: 'Fiat code'),
          const SizedBox(height: 16),
          CurrencyTextField(
              controller: fiatAmountController, label: 'Fiat amount'),
          const SizedBox(height: 16),
          _buildFixedToggle(),
          const SizedBox(height: 16),
          _buildTextField('Sats amount', satsAmountController,
              suffix: Icon(BitcoinIcons.satoshi_v1_outline).icon),
          const SizedBox(height: 16),
          _buildTextField('Payment method', paymentMethodController),
          const SizedBox(height: 32),
        ],
      );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {IconData? suffix}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.dark1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: AppTheme.cream1),
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: const TextStyle(color: AppTheme.grey2),
          suffixIcon:
              suffix != null ? Icon(suffix, color: AppTheme.grey2) : null,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter a value';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildFixedToggle() {
    return Row(
      children: [
        const Text('Fixed', style: TextStyle(color: AppTheme.cream1)),
        const SizedBox(width: 8),
        Switch(
          value: false,
          onChanged: (value) {},
        ),
      ],
    );
  }

}
