import 'package:bitcoin_icons/bitcoin_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mostro_mobile/app/app_theme.dart';
import 'package:mostro_mobile/presentation/widgets/currency_dropdown.dart';
import 'package:mostro_mobile/presentation/widgets/currency_text_field.dart';

class BuyFormWidget extends HookConsumerWidget {
  const BuyFormWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(() => GlobalKey<FormState>());

    final fiatAmountController = useTextEditingController();
    final satsAmountController = useTextEditingController();
    final paymentMethodController = useTextEditingController();
    final lightningInvoiceController = useTextEditingController();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
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
          _buildTextField('Lightning Invoice without an amount',
              lightningInvoiceController),
          const SizedBox(height: 16),
          _buildTextField('Payment method', paymentMethodController),
          const SizedBox(height: 32),
          _buildActionButtons(context, ref, formKey),
        ],
      ),
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

  Widget _buildActionButtons(
      BuildContext context, WidgetRef ref, GlobalKey<FormState> formKey) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => context.go('/'),
          child: const Text('CANCEL', style: TextStyle(color: AppTheme.red2)),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              //_submitOrder(context, ref, OrderType.buy);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.mostroGreen,
          ),
          child: const Text('SUBMIT'),
        ),
      ],
    );
  }


}
