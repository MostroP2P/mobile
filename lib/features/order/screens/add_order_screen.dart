import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as nostr_action;
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/shared/widgets/mostro_reactive_button.dart';
import 'package:uuid/uuid.dart';

class AddOrderScreen extends ConsumerStatefulWidget {
  const AddOrderScreen({super.key});

  @override
  ConsumerState<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends ConsumerState<AddOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fiatAmountController = TextEditingController();
  final _lightningAddressController = TextEditingController();
  final _scrollController = ScrollController();

  bool _marketRate = true;
  double _premiumValue = 0.0;
  int? _requestId;
  OrderType _orderType = OrderType.sell;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final GoRouterState state = GoRouterState.of(context);
      final extras = state.extra;

      if (extras != null && extras is Map<String, dynamic>) {
        final orderTypeStr = extras['orderType'] as String?;
        if (orderTypeStr == 'buy') {
          setState(() {
            _orderType = OrderType.buy;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fiatAmountController.dispose();
    _lightningAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF171A23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171A23),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'CREATING NEW ORDER',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Nuevo: Tarjeta con esquinas redondeadas para el tipo de orden
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 0),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E2230),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: Text(
                    _orderType == OrderType.buy
                        ? 'You want to buy Bitcoin'
                        : 'You want to sell Bitcoin',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              // Contenido principal con scroll
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCurrencySection(),
                        const SizedBox(height: 16),
                        _buildAmountSection(),
                        const SizedBox(height: 16),
                        _buildPaymentMethodsSection(),
                        const SizedBox(height: 16),
                        _buildPriceTypeSection(),
                        const SizedBox(height: 16),
                        _buildPremiumSection(),
                        const SizedBox(height: 16),
                        if (_orderType == OrderType.buy)
                          _buildLightningAddressSection(),
                        // Add buttons at the end of the form
                        const SizedBox(height: 32),
                        Container(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.only(top: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Botón Cancelar
                              SizedBox(
                                width: 100,
                                child: ElevatedButton(
                                  onPressed: () => context.pop(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E2230),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Botón Enviar
                              SizedBox(
                                width: 100,
                                child: ElevatedButton(
                                  onPressed: _submitOrder,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF764BA2),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Submit'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencySection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              _orderType == OrderType.buy
                  ? 'Select the fiat currency you will pay with'
                  : 'Select the Fiat Currency you want to receive',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF764BA2).withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      '\$',
                      style: TextStyle(color: Color(0xFF8CC63F), fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/flags/us.png',
                            width: 24,
                            height: 16,
                            errorBuilder: (context, error, stackTrace) {
                              return const Text('🇺🇸',
                                  style: TextStyle(fontSize: 18));
                            },
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'USD - US Dollar',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      const Icon(Icons.keyboard_arrow_down,
                          color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.1),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              _orderType == OrderType.buy
                  ? 'Enter the fiat amount you want to pay (you can set a range)'
                  : 'Enter the fiat amount you want to receive (you can set a range)',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8CC63F).withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.credit_card,
                    color: Color(0xFF8CC63F),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _fiatAmountController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Enter amount',
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.1),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Payment methods',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8CC63F).withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.credit_card,
                    color: Color(0xFF8CC63F),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Select payment methods',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Icon(Icons.keyboard_arrow_down, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.1),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceTypeSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  'Price type ',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.white.withOpacity(0.5),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Market price',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w500),
                ),
                Row(
                  children: [
                    Text(
                      'Market',
                      style: TextStyle(
                        color:
                            _marketRate ? const Color(0xFF8CC63F) : Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    Switch(
                      value: _marketRate,
                      activeColor: const Color(0xFF764BA2),
                      onChanged: (value) {
                        setState(() {
                          _marketRate = value;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  'Premium (%) ',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.white.withOpacity(0.5),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Valor del premium en un círculo a la derecha
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFF764BA2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _premiumValue.toStringAsFixed(1),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Slider
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: const Color(0xFF764BA2),
                    inactiveTrackColor: Colors.grey[800],
                    thumbColor: Colors.white,
                    overlayColor: const Color(0xFF764BA2).withOpacity(0.2),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _premiumValue,
                    min: -10,
                    max: 10,
                    divisions: 200,
                    onChanged: (value) {
                      setState(() {
                        _premiumValue = value;
                      });
                    },
                  ),
                ),
                // Etiquetas min y max
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        '-10%',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                      Text(
                        '+10%',
                        style:
                            TextStyle(color: Color(0xFF8CC63F), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLightningAddressSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Lightning Address (optional)',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bolt,
                    color: Colors.amber,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _lightningAddressController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Enter lightning address',
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.1),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ],
      ),
    );
  }

  void _submitOrder() {
    if (_formKey.currentState?.validate() ?? false) {
      // Aquí iría la lógica para enviar la orden

      // Muestra mensaje de éxito y vuelve atrás
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order submitted successfully'),
          duration: Duration(seconds: 2),
        ),
      );

      context.pop();
    }
  }
}
