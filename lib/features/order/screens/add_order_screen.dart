import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/order/widgets/action_buttons.dart';
import 'package:mostro_mobile/features/order/widgets/amount_section.dart';
import 'package:mostro_mobile/features/order/widgets/currency_section.dart';
import 'package:mostro_mobile/features/order/widgets/lightning_address_section.dart';
import 'package:mostro_mobile/features/order/widgets/order_type_header.dart';
import 'package:mostro_mobile/features/order/widgets/payment_methods_section.dart';
import 'package:mostro_mobile/features/order/widgets/premium_section.dart';
import 'package:mostro_mobile/features/order/widgets/price_type_section.dart';
import 'package:mostro_mobile/features/order/widgets/form_section.dart';
import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';
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
  final _satsAmountController = TextEditingController();

  bool _marketRate = true;
  double _premiumValue = 0.0;
  OrderType _orderType = OrderType.sell;
  int? _currentRequestId;

  int? _minFiatAmount;
  int? _maxFiatAmount;

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
    _satsAmountController.dispose();
    super.dispose();
  }

  void _parseFiatAmount(String input) {
    if (input.contains('-')) {
      final parts = input.split('-');
      if (parts.length == 2) {
        setState(() {
          _minFiatAmount = int.tryParse(parts[0].trim());
          _maxFiatAmount = int.tryParse(parts[1].trim());
        });
      }
    } else {
      setState(() {
        _minFiatAmount = int.tryParse(input);
        _maxFiatAmount = null;
      });
    }
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
              OrderTypeHeader(orderType: _orderType),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CurrencySection(
                          orderType: _orderType,
                          onCurrencySelected: () {
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 16),
                        AmountSection(
                          orderType: _orderType,
                          controller: _fiatAmountController,
                          onAmountChanged: _parseFiatAmount,
                        ),
                        const SizedBox(height: 16),
                        PaymentMethodsSection(
                          selectedMethods: _selectedPaymentMethods,
                          showCustomField: _showCustomPaymentMethod,
                          customController: _customPaymentMethodController,
                          onMethodsChanged: (methods, showCustom) {
                            setState(() {
                              _selectedPaymentMethods = methods;
                              _showCustomPaymentMethod = showCustom;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        PriceTypeSection(
                          isMarketRate: _marketRate,
                          onToggle: (value) {
                            setState(() {
                              _marketRate = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        // Conditionally show Premium section for market rate
                        if (_marketRate) ...[  
                          PremiumSection(
                            value: _premiumValue,
                            onChanged: (value) {
                              setState(() {
                                _premiumValue = value;
                              });
                            },
                          ),
                        ] else ...[  
                          // Show sats amount input field for fixed price
                          FormSection(
                            title: _orderType == OrderType.buy
                                ? 'Enter the Sats amount you want to Buy'
                                : 'Enter the Sats amount you want to Sell',
                            icon: const Icon(Icons.bolt, color: Color(0xFFF3CA29), size: 18),
                            iconBackgroundColor: const Color(0xFFF3CA29).withOpacity(0.3),
                            child: TextFormField(
                              controller: _satsAmountController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Enter sats amount',
                                hintStyle: TextStyle(color: Colors.grey),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (!_marketRate && (value == null || value.isEmpty)) {
                                  return 'Please enter sats amount';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (_orderType == OrderType.buy) ...[
                          LightningAddressSection(
                            controller: _lightningAddressController,
                          ),
                          const SizedBox(height: 16),
                        ],
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
                          child: ActionButtons(
                            onCancel: () => context.pop(),
                            onSubmit: _submitOrder,
                            currentRequestId: _currentRequestId,
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

  void _submitOrder() {
    if (_formKey.currentState?.validate() ?? false) {
      final selectedFiatCode = ref.read(selectedFiatCodeProvider);

      if (selectedFiatCode.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a currency'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      if (_selectedPaymentMethods.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one payment method'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      try {
        final uuid = const Uuid();
        final tempOrderId = uuid.v4();
        final notifier = ref.read(
          addOrderNotifierProvider(tempOrderId).notifier,
        );

        final requestId = notifier.requestId;

        setState(() {
          _currentRequestId = requestId;
        });

        final fiatAmount = _maxFiatAmount != null ? 0 : _minFiatAmount;
        final minAmount = _maxFiatAmount != null ? _minFiatAmount : null;
        final maxAmount = _maxFiatAmount;

        final satsAmount = int.tryParse(_satsAmountController.text) ?? 0;

        // Preparar la lista de métodos de pago para cumplir con NIP-69
        List<String> paymentMethods =
            List<String>.from(_selectedPaymentMethods);
        if (_showCustomPaymentMethod &&
            _customPaymentMethodController.text.isNotEmpty) {
          // Eliminar "Other" de la lista si existe para evitar duplicación
          paymentMethods.remove("Other");
          // Agregar el método de pago personalizado
          paymentMethods.add(_customPaymentMethodController.text);
        }

        // Cada método de pago se mantiene como un elemento separado en la lista
        // en lugar de concatenarlos en una cadena

        final buyerInvoice = _orderType == OrderType.buy &&
                _lightningAddressController.text.isNotEmpty
            ? _lightningAddressController.text
            : null;

        final order = Order(
          kind: _orderType,
          fiatCode: selectedFiatCode,
          fiatAmount: fiatAmount!,
          minAmount: minAmount,
          maxAmount: maxAmount,
          paymentMethods: paymentMethods, // Pasando la lista directamente
          amount: _marketRate ? 0 : satsAmount,
          premium: _marketRate ? _premiumValue.toInt() : 0,
          buyerInvoice: buyerInvoice,
        );

        notifier.submitOrder(order);
      } catch (e) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E2230),
              title: const Text('Error', style: TextStyle(color: Colors.white)),
              content: Text(e.toString(),
                  style: const TextStyle(color: Colors.white)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK',
                      style: TextStyle(color: Color(0xFF8CC63F))),
                ),
              ],
            ),
          );
        }
      }
    }
  }
}
