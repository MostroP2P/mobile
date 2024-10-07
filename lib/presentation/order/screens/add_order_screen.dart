import 'dart:convert';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:mostro_mobile/presentation/home/bloc/home_state.dart';
import 'package:mostro_mobile/presentation/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/presentation/widgets/custom_app_bar.dart';
import 'package:mostro_mobile/services/nostr_service.dart'; // Importa el servicio NostrService
import 'package:mostro_mobile/data/models/nostr_event.dart'; // Importa NostrEvent

class AddOrderScreen extends StatefulWidget {
  const AddOrderScreen({super.key});

  @override
  _AddOrderScreenState createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends State<AddOrderScreen> {
  OrderType _currentType = OrderType.sell;
  final _fiatCodeController = TextEditingController();
  final _fiatAmountController = TextEditingController();
  final _satsAmountController = TextEditingController();
  final _paymentMethodController = TextEditingController();
  final NostrService nostrService =
      NostrService(); // Instancia del servicio Nostr

  @override
  void initState() {
    super.initState();
    initNostr();
  }

  Future<void> initNostr() async {
    await nostrService.init(); // Asegura la inicialización de Nostr al comenzar
  }

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
          _buildTextField('Fiat code', _fiatCodeController),
          const SizedBox(height: 16),
          _buildTextField('Fiat amount', _fiatAmountController),
          const SizedBox(height: 16),
          _buildTextField('Sats amount', _satsAmountController),
          const SizedBox(height: 16),
          _buildTextField('Payment method', _paymentMethodController),
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
          _buildTextField('Fiat code', _fiatCodeController),
          const SizedBox(height: 16),
          _buildTextField('Fiat amount', _fiatAmountController),
          const SizedBox(height: 16),
          _buildTextField('Sats amount', _satsAmountController),
          const SizedBox(height: 16),
          _buildTextField('Payment method', _paymentMethodController),
          const SizedBox(height: 32),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
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
        ),
      ),
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
          onPressed: _submitOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8CC541),
          ),
          child: const Text('SUBMIT'),
        ),
      ],
    );
  }

  void _submitOrder() async {
    final fiatCode = _fiatCodeController.text.trim();
    final fiatAmount = double.tryParse(_fiatAmountController.text.trim()) ?? 0;
    final satsAmount = int.tryParse(_satsAmountController.text.trim()) ?? 0;
    final paymentMethod = _paymentMethodController.text.trim();

    if (fiatCode.isEmpty || fiatAmount <= 0 || paymentMethod.isEmpty) {
      _showErrorDialog('Please fill all fields correctly.');
      return;
    }

    // Crear y configurar un nuevo NostrEvent
    var event = P2POrderEvent.create(
        privateKey: 'your_private_key_here',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        tags: [
          [
            'p',
            'npub1n5yrh6lkvc0l3lcmcfwake4r3ex7jrm0e6lumsc22d8ylf7jwk0qack9tq'
          ],
          ['k', _currentType == OrderType.sell ? 'sell' : 'buy'],
          ['f', fiatCode],
          ['amt', satsAmount.toString()],
          ['fa', fiatAmount.toString()],
          ['pm', paymentMethod]
        ],
        content: jsonEncode({'message': 'Creating new order'}));

    // Asegúrate de que NostrService esté inicializado antes de usarlo
    if (!nostrService.isInitialized) {
      await nostrService.init();
    }
    await nostrService.publishEvent(
        event as NostrEvent); // Usar el método de publicación adecuado
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
