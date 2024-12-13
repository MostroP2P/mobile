import 'package:bitcoin_icons/bitcoin_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/theme/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/presentation/add_order/bloc/add_order_bloc.dart';
import 'package:mostro_mobile/presentation/add_order/bloc/add_order_event.dart';
import 'package:mostro_mobile/presentation/add_order/bloc/add_order_state.dart';
import 'package:mostro_mobile/presentation/widgets/currency_dropdown.dart';
import 'package:mostro_mobile/presentation/widgets/currency_text_field.dart';
import 'package:mostro_mobile/providers/exchange_service_provider.dart';
import 'package:mostro_mobile/providers/riverpod_providers.dart';

class AddOrderScreen extends ConsumerWidget {
  final _formKey = GlobalKey<FormState>();

  AddOrderScreen({super.key});

  final _fiatAmountController = TextEditingController();
  final _satsAmountController = TextEditingController();
  final _paymentMethodController = TextEditingController();
  final _lightningInvoiceController = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderRepo = ref.watch(mostroServiceProvider);

    return BlocProvider(
      create: (context) => AddOrderBloc(orderRepo),
      child: BlocBuilder<AddOrderBloc, AddOrderState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: AppTheme.dark1,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon:
                    const HeroIcon(HeroIcons.arrowLeft, color: AppTheme.cream1),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                'NEW ORDER',
                style: TextStyle(
                  color: AppTheme.cream1,
                  fontFamily: GoogleFonts.robotoCondensed().fontFamily,
                ),
              ),
            ),
            body: Column(
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.dark2,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _buildContent(context, state, ref),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, AddOrderState state, WidgetRef ref) {
    if (state.status == AddOrderStatus.submitting) {
      return Center(child: CircularProgressIndicator());
    } else if (state.status == AddOrderStatus.submitted) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(S.of(context).new_order('24'),
              style: TextStyle(fontSize: 18, color: AppTheme.cream1),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      );
    } else if (state.status == AddOrderStatus.failure) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Order failed: ${state.errorMessage}',
              style: const TextStyle(fontSize: 18, color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      );
    } else {
      return Form(
        key: _formKey,
        child: Column(
          children: [
            _buildTabs(context, state),
            Expanded(
              child: state.currentType == OrderType.sell
                  ? _buildSellForm(context, ref)
                  : _buildBuyForm(context, ref),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildTabs(BuildContext context, AddOrderState state) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.dark1,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTab(context, "SELL",
                state.currentType == OrderType.sell, OrderType.sell),
          ),
          Expanded(
            child: _buildTab(context, "BUY", state.currentType == OrderType.buy,
                OrderType.buy),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(
      BuildContext context, String text, bool isActive, OrderType type) {
    return GestureDetector(
      onTap: () {
        context.read<AddOrderBloc>().add(ChangeOrderType(type));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.dark2 : AppTheme.dark1,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isActive ? 20 : 0),
            topRight: Radius.circular(isActive ? 20 : 0),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? AppTheme.cream1 : AppTheme.grey2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSellForm(BuildContext context, WidgetRef ref) {
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
              controller: _fiatAmountController, label: 'Fiat amount'),
          const SizedBox(height: 16),
          _buildFixedToggle(),
          const SizedBox(height: 16),
          _buildTextField('Sats amount', _satsAmountController,
              suffix: Icon(BitcoinIcons.satoshi_v1_outline).icon),
          const SizedBox(height: 16),
          _buildTextField('Payment method', _paymentMethodController),
          const SizedBox(height: 32),
          _buildActionButtons(context, ref, OrderType.sell),
        ],
      ),
    );
  }

  Widget _buildBuyForm(BuildContext context, WidgetRef ref) {
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
              controller: _fiatAmountController, label: 'Fiat amount'),
          const SizedBox(height: 16),
          _buildFixedToggle(),
          const SizedBox(height: 16),
          _buildTextField('Sats amount', _satsAmountController,
              suffix: Icon(BitcoinIcons.satoshi_v1_outline).icon),
          const SizedBox(height: 16),
          _buildTextField('Lightning Invoice without an amount',
              _lightningInvoiceController),
          const SizedBox(height: 16),
          _buildTextField('Payment method', _paymentMethodController),
          const SizedBox(height: 32),
          _buildActionButtons(context, ref, OrderType.buy),
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
          onChanged: (value) {
            // Update the state in the bloc if necessary
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons(
      BuildContext context, WidgetRef ref, OrderType orderType) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL', style: TextStyle(color: AppTheme.red2)),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              _submitOrder(context, ref, orderType);
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

  void _submitOrder(BuildContext context, WidgetRef ref, OrderType orderType) {
    final selectedFiatCode = ref.read(selectedFiatCodeProvider);

    if (_formKey.currentState?.validate() ?? false) {
      context.read<AddOrderBloc>().add(SubmitOrder(
            fiatCode: selectedFiatCode ?? '', // Use selected fiat code
            fiatAmount: int.tryParse(_fiatAmountController.text) ?? 0,
            satsAmount: int.tryParse(_satsAmountController.text) ?? 0,
            paymentMethod: _paymentMethodController.text,
            orderType: orderType,
          ));
    }
  }
}
