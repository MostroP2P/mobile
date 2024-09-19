import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:mostro_mobile/features/home/presentation/bloc/home_event.dart';
import 'package:mostro_mobile/features/home/presentation/bloc/home_state.dart';
import 'package:mostro_mobile/features/home/presentation/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/features/home/presentation/widgets/custom_app_bar.dart';

class AddOrderScreen extends StatefulWidget {
  const AddOrderScreen({super.key});

  @override
  _AddOrderScreenState createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends State<AddOrderScreen> {
  OrderType _currentType = OrderType.sell;

  @override
  Widget build(BuildContext context) {
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
                  _buildTabs(),
                  Expanded(
                    child: _currentType == OrderType.sell
                        ? _buildSellForm()
                        : _buildBuyForm(),
                  ),
                ],
              ),
            ),
          ),
          const BottomNavBar(),
        ],
      ),
    );
  }

  Widget _buildTabs() {
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
            child: _buildTab(
                "SELL BTC", _currentType == OrderType.sell, OrderType.sell),
          ),
          Expanded(
            child: _buildTab(
                "BUY BTC", _currentType == OrderType.buy, OrderType.buy),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String text, bool isActive, OrderType type) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentType = type;
        });
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
            color: isActive ? const Color(0xFF8CC541) : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSellForm() {
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
          _buildTextField('Fiat amount'),
          const SizedBox(height: 16),
          _buildSwitchField('Fixed'),
          const SizedBox(height: 16),
          _buildTextField('Sats amount'),
          const SizedBox(height: 16),
          _buildDropdownField('Payment method'),
          const SizedBox(height: 32),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildBuyForm() {
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
          _buildTextField('Fiat amount'),
          const SizedBox(height: 16),
          _buildSwitchField('Fixed'),
          const SizedBox(height: 16),
          _buildTextField('Sats amount'),
          const SizedBox(height: 16),
          _buildTextField('Lightning Invoice without an amount'),
          const SizedBox(height: 16),
          _buildDropdownField('Payment method'),
          const SizedBox(height: 32),
          _buildActionButtons(),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white)),
          const Icon(Icons.arrow_drop_down, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildTextField(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1D212C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildSwitchField(String label) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        Switch(
          value: false,
          onChanged: (value) {},
          activeColor: const Color(0xFF8CC541),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
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
            // Implement submit logic
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
