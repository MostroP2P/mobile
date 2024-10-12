import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mostro_mobile/presentation/add_order/bloc/add_order_bloc.dart';
import 'package:mostro_mobile/presentation/add_order/bloc/add_order_event.dart';
import 'package:mostro_mobile/presentation/add_order/bloc/add_order_state.dart';
import 'package:mostro_mobile/presentation/home/bloc/home_state.dart';
import 'package:mostro_mobile/presentation/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/presentation/widgets/custom_app_bar.dart';

class AddOrderScreen extends StatelessWidget {
  AddOrderScreen({Key? key}) : super(key: key);

  final _fiatCodeController = TextEditingController();
  final _fiatAmountController = TextEditingController();
  final _satsAmountController = TextEditingController();
  final _paymentMethodController = TextEditingController();
  final _lightningInvoiceController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AddOrderBloc(),
      child: BlocBuilder<AddOrderBloc, AddOrderState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: const Color(0xFF1D212C),
            appBar: const CustomAppBar(),
            body: Column(
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF303544),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        _buildTabs(context, state),
                        Expanded(
                          child: state.currentType == OrderType.sell
                              ? _buildSellForm(context)
                              : _buildBuyForm(context),
                        ),
                      ],
                    ),
                  ),
                ),
                const BottomNavBar(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabs(BuildContext context, AddOrderState state) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1D212C),
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
          color: isActive ? const Color(0xFF303544) : const Color(0xFF1D212C),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isActive ? 20 : 0),
            topRight: Radius.circular(isActive ? 20 : 0),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSellForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Make sure your order is below 20K sats',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          _buildDropdownField('Fiat code'),
          const SizedBox(height: 16),
          _buildTextField('Fiat amount', _fiatAmountController),
          const SizedBox(height: 16),
          _buildFixedToggle(),
          const SizedBox(height: 16),
          _buildTextField('Sats amount', _satsAmountController,
              suffix: Icons.menu),
          const SizedBox(height: 16),
          _buildTextField('Payment method', _paymentMethodController),
          const SizedBox(height: 32),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildBuyForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Make sure your order is below 20K sats',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          _buildDropdownField('Fiat code'),
          const SizedBox(height: 16),
          _buildTextField('Fiat amount', _fiatAmountController),
          const SizedBox(height: 16),
          _buildFixedToggle(),
          const SizedBox(height: 16),
          _buildTextField('Sats amount', _satsAmountController,
              suffix: Icons.menu),
          const SizedBox(height: 16),
          _buildTextField('Lightning Invoice without an amount',
              _lightningInvoiceController),
          const SizedBox(height: 16),
          _buildTextField('Payment method', _paymentMethodController),
          const SizedBox(height: 32),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildDropdownField(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1D212C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
        ),
        dropdownColor: const Color(0xFF1D212C),
        style: const TextStyle(color: Colors.white),
        items: const [], // Add your fiat code options here
        onChanged: (value) {},
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {IconData? suffix}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1D212C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          suffixIcon: suffix != null ? Icon(suffix, color: Colors.grey) : null,
        ),
      ),
    );
  }

  Widget _buildFixedToggle() {
    return Row(
      children: [
        const Text('Fixed', style: TextStyle(color: Colors.white)),
        const SizedBox(width: 8),
        Switch(
          value: false, // You should manage this state in the bloc
          onChanged: (value) {
            // Update the state in the bloc
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('CANCEL', style: TextStyle(color: Colors.orange)),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: () {
            // For now, just print the values and close the screen
            print('Fiat Code: ${_fiatCodeController.text}');
            print('Fiat Amount: ${_fiatAmountController.text}');
            print('Sats Amount: ${_satsAmountController.text}');
            print('Payment Method: ${_paymentMethodController.text}');
            if (_lightningInvoiceController.text.isNotEmpty) {
              print('Lightning Invoice: ${_lightningInvoiceController.text}');
            }
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8CC541),
          ),
          child: const Text('SUBMIT'),
        ),
      ],
    );
  }
}
