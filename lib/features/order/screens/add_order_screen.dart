import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
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
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/utils/snack_bar_helper.dart';

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
  String? _validationError;
  bool _isRangeMode = false;
  String? _fixedPriceRangeError;
  Timer? _fixedPriceRangeErrorTimer;

  List<String> _selectedPaymentMethods = [];

  @override
  void initState() {
    super.initState();
    _customPaymentMethodController.addListener(_onCustomPaymentMethodChanged);

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
      ref.read(selectedFiatCodeProvider.notifier).state =
          settings.defaultFiatCode;

      // Pre-populate lightning address from settings if available
      if (settings.defaultLightningAddress != null &&
          settings.defaultLightningAddress!.isNotEmpty) {
        _lightningAddressController.text = settings.defaultLightningAddress!;
      }
    });
  }

  @override
  void dispose() {
    _fixedPriceRangeErrorTimer?.cancel();
    _scrollController.dispose();
    _lightningAddressController.dispose();
    _customPaymentMethodController.removeListener(_onCustomPaymentMethodChanged);
    _customPaymentMethodController.dispose();
    _satsAmountController.dispose();
    super.dispose();
  }

  void _onCustomPaymentMethodChanged() {
    setState(() {});
  }

  void _onAmountChanged(int? minAmount, int? maxAmount) {
    setState(() {
      _minFiatAmount = minAmount;
      _maxFiatAmount = maxAmount;

      // Use comprehensive validation to check all error conditions
      _validationError = _validateAllAmounts();
    });
  }

  void _showFixedPriceRangeError() {
    _fixedPriceRangeErrorTimer?.cancel();
    setState(() {
      _fixedPriceRangeError = S.of(context)!.fixedPriceDisabledForRange;
    });
    _fixedPriceRangeErrorTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _fixedPriceRangeError = null;
        });
      }
    });
  }

  void _onRangeModeChanged(bool isRange) {
    final wasFixedPrice = !_marketRate;
    setState(() {
      _isRangeMode = isRange;
      if (isRange && wasFixedPrice) {
        _marketRate = true;
        _satsAmountController.clear();
      }
      if (!isRange) {
        _fixedPriceRangeError = null;
      }
      _validationError = _validateAllAmounts();
    });
    if (isRange && wasFixedPrice) {
      _showFixedPriceRangeError();
    }
  }

  /// Converts fiat amount to sats using exchange rate
  /// Formula: fiatAmount / exchangeRate * 100000000 (sats per BTC)
  int _calculateSatsFromFiat(double fiatAmount, double exchangeRate) {
    if (exchangeRate <= 0) return 0;
    return (fiatAmount / exchangeRate * 100000000).round();
  }

  /// Validates if sats amount is within mostro instance allowed range
  /// Returns error message if validation fails or data is missing
  String? _validateSatsRange(double fiatAmount) {
    // Ensure fiat code is selected
    final selectedFiatCode = ref.read(selectedFiatCodeProvider);
    if (selectedFiatCode == null || selectedFiatCode.isEmpty) {
      return S.of(context)!.pleaseSelectCurrency;
    }

    // Get exchange rate - return error if not available
    final exchangeRateAsync = ref.read(exchangeRateProvider(selectedFiatCode));
    final exchangeRate = exchangeRateAsync.asData?.value;
    if (exchangeRate == null) {
      // Check if it's loading or error
      if (exchangeRateAsync.isLoading) {
        return S.of(context)!.exchangeRateNotAvailable;
      } else if (exchangeRateAsync.hasError) {
        return S.of(context)!.exchangeRateNotAvailable;
      }
      // Fallback for any other case where rate is null
      return S.of(context)!.exchangeRateNotAvailable;
    }

    // Get mostro instance limits - return error if not available
    final mostroInstance = ref.read(orderRepositoryProvider).mostroInstance;
    if (mostroInstance == null) {
      return S.of(context)!.mostroInstanceNotAvailable;
    }

    // Calculate sats equivalent
    final satsAmount = _calculateSatsFromFiat(fiatAmount, exchangeRate);
    final minAllowed = mostroInstance.minOrderAmount;
    final maxAllowed = mostroInstance.maxOrderAmount;

    // Debug logging
    debugPrint(
        'Validation: fiat=$fiatAmount, rate=$exchangeRate, sats=$satsAmount, min=$minAllowed, max=$maxAllowed');

    // Check if sats amount is outside range
    if (satsAmount < minAllowed) {
      return S.of(context)!.fiatAmountTooLow(
            minAllowed.toString(),
            maxAllowed.toString(),
          );
    } else if (satsAmount > maxAllowed) {
      return S.of(context)!.fiatAmountTooHigh(
            minAllowed.toString(),
            maxAllowed.toString(),
          );
    }

    // Validation passed
    return null;
  }

  /// Comprehensive validation for all fiat amount inputs
  /// Returns error message if validation fails, null if all validations pass
  String? _validateAllAmounts() {
    // Check min/max relationship for range orders
    if (_minFiatAmount != null && _maxFiatAmount != null) {
      if (_maxFiatAmount! <= _minFiatAmount!) {
        return S.of(context)!.maxMustBeGreaterThanMin;
      }
    }

    // Check sats range validation for min amount
    if (_minFiatAmount != null) {
      final minError = _validateSatsRange(_minFiatAmount!.toDouble());
      if (minError != null) return minError;
    }

    // Check sats range validation for max amount
    if (_maxFiatAmount != null) {
      final maxError = _validateSatsRange(_maxFiatAmount!.toDouble());
      if (maxError != null) return maxError;
    }

    return null; // All validations passed
  }

  @override
  Widget build(BuildContext context) {
    // Proactively fetch exchange rate when currency is selected
    // This triggers the fetch before user enters amounts, preventing "exchangeRateNotAvailable" error
    final selectedFiatCode = ref.watch(selectedFiatCodeProvider);
    if (selectedFiatCode != null && selectedFiatCode.isNotEmpty) {
      ref.watch(exchangeRateProvider(selectedFiatCode));
    }

    // Listen for fiat code changes and reset payment methods when currency changes
    // This prevents stale payment methods from previous currency selection
    ref.listen<String?>(selectedFiatCodeProvider, (previous, next) {
      // Only reset if there was a previous value and it changed
      // Skip on initial load (previous == null)
      if (previous != null && previous != next && context.mounted) {
        setState(() {
          _selectedPaymentMethods = [];
          _customPaymentMethodController.clear();
        });
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
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
                            setState(() {
                              // Re-validate after currency change since rates/limits differ
                              _validationError = _validateAllAmounts();
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        AmountSection(
                          orderType: _orderType,
                          onAmountChanged: _onAmountChanged,
                          validateSatsRange: _validateSatsRange,
                          validationError: _validationError,
                          onRangeModeChanged: _onRangeModeChanged,
                        ),
                        const SizedBox(height: 16),
                        PaymentMethodsSection(
                          selectedMethods: _selectedPaymentMethods,
                          customController: _customPaymentMethodController,
                          onMethodsChanged: (methods) {
                            setState(() {
                              _selectedPaymentMethods = methods;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        PriceTypeSection(
                          isMarketRate: _marketRate,
                          errorMessage: _fixedPriceRangeError,
                          onToggle: (value) {
                            if (!value && _isRangeMode) {
                              _showFixedPriceRangeError();
                              return;
                            }
                            setState(() {
                              _fixedPriceRangeError = null;
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
                                color: AppTheme.yellow, size: 18),
                            iconBackgroundColor:
                                AppTheme.yellow.withValues(alpha: 0.3),
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
                            onSubmit: _getSubmitCallback(),
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

  /// Returns submit callback only when form is valid, null otherwise
  /// This prevents button loading state when validation errors exist
  VoidCallback? _getSubmitCallback() {
    // Don't allow submission if validation errors exist
    if (_validationError != null) {
      return null; // Disables button, prevents loading state
    }

    // Ensure at least a minimum amount is entered
    if (_minFiatAmount == null) {
      return null;
    }

    // Check other basic conditions that would prevent submission
    final selectedFiatCode = ref.read(selectedFiatCodeProvider);
    if (selectedFiatCode == null || selectedFiatCode.isEmpty) {
      return null;
    }

    if (_selectedPaymentMethods.isEmpty &&
        _customPaymentMethodController.text.trim().isEmpty) {
      return null;
    }

    return _submitOrder; // Form is valid - allow submission
  }

  void _submitOrder() {
    if (_formKey.currentState?.validate() ?? false) {
      final selectedFiatCode = ref.read(selectedFiatCodeProvider);

      if (selectedFiatCode == null || selectedFiatCode.isEmpty) {
        SnackBarHelper.showTopSnackBar(
          context,
          S.of(context)!.pleaseSelectCurrency,
        );
        return;
      }

      // Now we know selectedFiatCode is non-null and non-empty
      final fiatCode = selectedFiatCode;

      if (_selectedPaymentMethods.isEmpty &&
          _customPaymentMethodController.text.trim().isEmpty) {
        SnackBarHelper.showTopSnackBar(
          context,
          S.of(context)!.pleaseSelectPaymentMethod,
        );
        return;
      }

      // Enhanced validation: check sats range for both min and max amounts
      // This is a critical final validation before submission
      if (_validationError != null) {
        debugPrint(
            'Submission blocked: Validation error present: $_validationError');
        // Validation error is already displayed inline, just prevent submission
        return;
      }

      // Additional safety check: ensure we have valid data for submission
      final exchangeRateAsync = ref.read(exchangeRateProvider(fiatCode));
      final mostroInstance = ref.read(orderRepositoryProvider).mostroInstance;

      if (!exchangeRateAsync.hasValue || mostroInstance == null) {
        debugPrint(
            'Submission blocked: Required data not available - Exchange rate: ${exchangeRateAsync.hasValue}, Mostro instance: ${mostroInstance != null}');
        SnackBarHelper.showTopSnackBar(
          context,
          S.of(context)!.exchangeRateNotAvailable,
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.orange.withValues(alpha: 0.8),
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
        if (_customPaymentMethodController.text.isNotEmpty) {
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
              backgroundColor: AppTheme.backgroundCard,
              title: Text(S.of(context)!.error,
                  style: const TextStyle(color: Colors.white)),
              content: Text(e.toString(),
                  style: const TextStyle(color: Colors.white)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(S.of(context)!.ok,
                      style: const TextStyle(color: AppTheme.mostroGreen)),
                ),
              ],
            ),
          );
        }
      }
    }
  }
}
