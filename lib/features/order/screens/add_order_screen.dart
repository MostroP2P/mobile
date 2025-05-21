import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as nostr_action;
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/providers/payment_methods_provider.dart';
import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';
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
  final _customPaymentMethodController = TextEditingController();

  bool _marketRate = true;
  double _premiumValue = 0.0;
  int? _requestId;
  OrderType _orderType = OrderType.sell;

  // Lista de métodos de pago seleccionados
  List<String> _selectedPaymentMethods = [];
  bool _showCustomPaymentMethod = false;

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
    _customPaymentMethodController.dispose();
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
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
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
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
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
    final selectedFiatCode = ref.watch(selectedFiatCodeProvider) ?? 'USD';
    final currenciesAsync = ref.watch(currencyCodesProvider);

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
          InkWell(
            onTap: () {
              _showCurrencySelectionDialog();
            },
            child: Container(
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
                        style:
                            TextStyle(color: Color(0xFF8CC63F), fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: currenciesAsync.when(
                      loading: () => const Text('Loading currencies...',
                          style: TextStyle(color: Colors.white)),
                      error: (_, __) => const Text('Error loading currencies',
                          style: TextStyle(color: Colors.red)),
                      data: (currencies) {
                        final currency = currencies[selectedFiatCode];
                        String flag = '🏳️';
                        String name = 'US Dollar';

                        if (currency != null) {
                          flag = currency.emoji;
                          name = currency.name;
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(flag,
                                    style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Text(
                                  '$selectedFiatCode - $name',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            const Icon(Icons.keyboard_arrow_down,
                                color: Colors.white),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
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

  void _showCurrencySelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF1E2230),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                backgroundColor: const Color(0xFF252a3a),
                title: const Text('Select Currency',
                    style: TextStyle(color: Colors.white)),
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                centerTitle: true,
                elevation: 0,
              ),
              Flexible(
                child: Consumer(
                  builder: (context, ref, child) {
                    final currenciesAsync = ref.watch(currencyCodesProvider);
                    return currenciesAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) => Center(
                        child: Text(
                          'Error loading currencies',
                          style: TextStyle(color: Colors.red.shade300),
                        ),
                      ),
                      data: (currencies) {
                        final selectedCode =
                            ref.watch(selectedFiatCodeProvider);
                        final sortedCurrencies = currencies.entries.toList()
                          ..sort((a, b) => a.key.compareTo(b.key));

                        return ListView.builder(
                          itemCount: sortedCurrencies.length,
                          itemBuilder: (context, index) {
                            final entry = sortedCurrencies[index];
                            final code = entry.key;
                            final currency = entry.value;
                            final isSelected = code == selectedCode;

                            return ListTile(
                              leading: Text(
                                currency.emoji.isNotEmpty
                                    ? currency.emoji
                                    : '🏳️',
                                style: const TextStyle(fontSize: 20),
                              ),
                              title: Text(
                                '$code - ${currency.name}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check,
                                      color: Color(0xFF8CC63F))
                                  : null,
                              onTap: () {
                                ref
                                    .read(selectedFiatCodeProvider.notifier)
                                    .state = code;
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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
    // Lista de métodos de pago disponibles para mostrar
    final availableMethods = [
      'Bank Transfer',
      'Cash in person',
      'Wise',
      'Revolut',
      'Other'
    ];

    // Texto a mostrar cuando no hay métodos seleccionados o cuando hay selecciones
    final displayText = _selectedPaymentMethods.isEmpty
        ? 'Select payment methods'
        : _selectedPaymentMethods.join(', ');

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
          InkWell(
            onTap: () {
              _showPaymentMethodsDialog(availableMethods);
            },
            child: Container(
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
                      children: [
                        Flexible(
                          child: Text(
                            displayText,
                            style: TextStyle(
                              color: _selectedPaymentMethods.isEmpty
                                  ? Colors.grey
                                  : Colors.white,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down,
                            color: Colors.white),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showCustomPaymentMethod) ...[
            // Mostrar campo para método personalizado
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextField(
                controller: _customPaymentMethodController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Enter custom payment method',
                  hintStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF8CC63F)),
                  ),
                ),
              ),
            ),
          ],
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.1),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ],
      ),
    );
  }

  // Muestra el diálogo para seleccionar métodos de pago
  void _showPaymentMethodsDialog(List<String> availableMethods) {
    // Asegurarnos de que 'Other' esté siempre disponible
    if (!availableMethods.contains('Other')) {
      availableMethods = [...availableMethods, 'Other'];
    }

    // Crear una copia local de los métodos seleccionados para el diálogo
    List<String> dialogSelectedMethods =
        List<String>.from(_selectedPaymentMethods);
    bool dialogShowOtherField = dialogSelectedMethods.contains('Other');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E2230),
              title: const Text(
                'Select Payment Methods',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...availableMethods.map((method) => CheckboxListTile(
                            title: Text(method,
                                style: const TextStyle(color: Colors.white)),
                            value: dialogSelectedMethods.contains(method),
                            activeColor: const Color(0xFF8CC63F),
                            checkColor: Colors.black,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (selected) {
                              setDialogState(() {
                                if (selected == true) {
                                  dialogSelectedMethods.add(method);
                                  if (method == 'Other') {
                                    dialogShowOtherField = true;
                                  }
                                } else {
                                  dialogSelectedMethods.remove(method);
                                  if (method == 'Other') {
                                    dialogShowOtherField = false;
                                  }
                                }
                              });
                            },
                          )),
                      if (dialogShowOtherField) ...[
                        // Mostrar campo para método personalizado en el diálogo
                        const SizedBox(height: 16),
                        StatefulBuilder(
                          builder: (context, setState) {
                            String customValue =
                                _customPaymentMethodController.text;
                            return TextField(
                              controller:
                                  TextEditingController(text: customValue),
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Enter custom payment method',
                                hintStyle: TextStyle(color: Colors.grey),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white24),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Color(0xFF8CC63F)),
                                ),
                              ),
                              onChanged: (value) {
                                customValue = value;
                                _customPaymentMethodController.text = value;
                              },
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white70)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedPaymentMethods = dialogSelectedMethods;
                      _showCustomPaymentMethod = dialogShowOtherField;
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Confirm',
                      style: TextStyle(color: Color(0xFF8CC63F))),
                ),
              ],
            );
          },
        );
      },
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
