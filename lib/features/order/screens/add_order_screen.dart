import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class AddOrderScreen extends ConsumerStatefulWidget {
  const AddOrderScreen({super.key});

  @override
  ConsumerState<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends ConsumerState<AddOrderScreen> {
  final _formKey = GlobalKey<FormState>();
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

      // Reset selectedFiatCodeProvider to default from settings for each new order
      final settings = ref.read(settingsProvider);
      ref.read(selectedFiatCodeProvider.notifier).state = settings.defaultFiatCode;
      
      // Pre-populate lightning address from settings if available
      if (settings.defaultLightningAddress != null && settings.defaultLightningAddress!.isNotEmpty) {
        _lightningAddressController.text = settings.defaultLightningAddress!;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _lightningAddressController.dispose();
    _customPaymentMethodController.dispose();
    _satsAmountController.dispose();
    super.dispose();
  }

  void _onAmountChanged(int? minAmount, int? maxAmount) {
    setState(() {
      _minFiatAmount = minAmount;
      _maxFiatAmount = maxAmount;
    });
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
        title: Text(
          S.of(context)!.creatingNewOrder,
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
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + MediaQuery.of(context).viewPadding.bottom,
                  ),
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
                          onAmountChanged: _onAmountChanged,
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
                                ? S.of(context)!.enterSatsAmountBuy
                                : S.of(context)!.enterSatsAmountSell,
                            icon: const Icon(Icons.bolt,
                                color: Color(0xFFF3CA29), size: 18),
                            iconBackgroundColor:
                                const Color(0xFFF3CA29).withValues(alpha: 0.3),
                            child: TextFormField(
                              controller: _satsAmountController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: S.of(context)!.enterSatsAmount,
                                hintStyle: const TextStyle(color: Colors.grey),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (!_marketRate &&
                                    (value == null || value.isEmpty)) {
                                  return S.of(context)!.pleaseEnterSatsAmount;
                                }
                                if (!_marketRate &&
                                    !RegExp(r'^[0-9]+$').hasMatch(value!)) {
                                  return S.of(context)!.pleaseEnterNumbersOnly;
                                }
                                return null;
                              },
                              // Restricting input to numbers only
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
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
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.only(top: 16),
                          child: ActionButtons(
                            key: const Key('addOrderButtons'),
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

      if (selectedFiatCode == null || selectedFiatCode.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context)!.pleaseSelectCurrency),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      // Now we know selectedFiatCode is non-null and non-empty
      final fiatCode = selectedFiatCode;

      if (_selectedPaymentMethods.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context)!.pleaseSelectPaymentMethod),
            duration: const Duration(seconds: 2),
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


        List<String> paymentMethods =
            List<String>.from(_selectedPaymentMethods);
        if (_showCustomPaymentMethod &&
            _customPaymentMethodController.text.isNotEmpty) {

          // Remove translated "Other" text from the list
          paymentMethods.removeWhere((method) => 
              method == S.of(context)!.other || 
              method == "Other" || 
              method == "Otro" || 
              method == "Altro");
          
          String sanitizedPaymentMethod = _customPaymentMethodController.text;
          
          final problematicChars = RegExp(r'[,"\\\[\]{}]');
          sanitizedPaymentMethod = sanitizedPaymentMethod
              .replaceAll(problematicChars, ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
              
          if (sanitizedPaymentMethod.isNotEmpty) {
            paymentMethods.add(sanitizedPaymentMethod);
          }
        }


        final buyerInvoice = _orderType == OrderType.buy &&
                _lightningAddressController.text.isNotEmpty
            ? _lightningAddressController.text
            : null;

        final order = Order(
          kind: _orderType,
          fiatCode: fiatCode,
          fiatAmount: fiatAmount!,
          minAmount: minAmount,
          maxAmount: maxAmount,
          paymentMethod: paymentMethods.join(','),
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
              title: Text(S.of(context)!.error,
                  style: const TextStyle(color: Colors.white)),
              content: Text(e.toString(),
                  style: const TextStyle(color: Colors.white)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(S.of(context)!.ok,
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
