import 'package:bitcoin_icons/bitcoin_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/order/widgets/fixed_switch_widget.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/shared/widgets/currency_combo_box.dart';
import 'package:mostro_mobile/shared/widgets/currency_text_field.dart';
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
  final _satsAmountController = TextEditingController();
  final _paymentMethodController = TextEditingController();
  final _lightningInvoiceController = TextEditingController();

  bool _marketRate = true; // false => Fixed, true => Market
  double _premiumValue = 0.0; // slider for -10..10
  bool _isEnabled = false; // controls enabled or not

  int? _minFiatAmount;
  int? _maxFiatAmount;

  @override
  Widget build(BuildContext context) {
    final orderType = ref.watch(orderTypeProvider);

    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const HeroIcon(HeroIcons.arrowLeft, color: AppTheme.cream1),
          onPressed: () => context.pop(),
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
              child: _buildContent(context, ref, orderType),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, OrderType orderType) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildTabs(context, ref, orderType),
          Expanded(
            child: orderType == OrderType.sell
                ? _buildSellForm(context, ref)
                : _buildBuyForm(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context, WidgetRef ref, OrderType orderType) {
    final currencyCode = ref.watch(selectedFiatCodeProvider);
    if (currencyCode != null && currencyCode.isNotEmpty) {
      _isEnabled = true;
    } else {
      _isEnabled = false;
    }
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
            child: _buildTab(context, ref, "SELL", orderType == OrderType.sell,
                OrderType.sell),
          ),
          Expanded(
            child: _buildTab(
                context, ref, "BUY", orderType == OrderType.buy, OrderType.buy),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, WidgetRef ref, String text,
      bool isActive, OrderType type) {
    return GestureDetector(
      onTap: () {
        // Update the local orderType state
        ref.read(orderTypeProvider.notifier).state = type;
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

  ///
  /// SELL FORM
  ///
  Widget _buildSellForm(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Make sure your order is below 20K sats',
              style: TextStyle(color: AppTheme.grey2)),
          const SizedBox(height: 16),

          // 1) Currency dropdown always enabled
          CurrencyComboBox(
            key: const Key("fiatCodeDropdown"),
            label: 'Fiat code',
            onSelected: (String fiatCode) {
              // Once a fiat code is selected, enable the other fields
              setState(() {
                _isEnabled = true;
              });
            },
          ),

          const SizedBox(height: 16),

          // 2) fiat amount
          _buildDisabledWrapper(
            enabled: _isEnabled,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.dark1,
                borderRadius: BorderRadius.circular(8),
              ),
              child: CurrencyTextField(
                key: const ValueKey('fiatAmountField'),
                controller: _fiatAmountController,
                label: 'Fiat amount',
                onChanged: (parsed) {
                  setState(() {
                    _minFiatAmount = parsed.$1;
                    _maxFiatAmount = parsed.$2;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 3) fixed/market toggle
          _buildDisabledWrapper(
            enabled: _isEnabled,
            child: FixedSwitch(
              initialValue: _marketRate,
              onChanged: (value) {
                setState(() {
                  _marketRate = value;
                });
              },
            ),
          ),

          const SizedBox(height: 16),

          // 4) either a text field for sats or a slider for premium
          _marketRate
              ? _buildDisabledWrapper(
                  enabled: _isEnabled,
                  child: _buildPremiumSlider(),
                )
              : _buildDisabledWrapper(
                  enabled: _isEnabled,
                  child: _buildTextField('Sats amount',
                      const Key('satsAmountField'), _satsAmountController,
                      suffix: Icon(BitcoinIcons.satoshi_v1_outline).icon),
                ),

          const SizedBox(height: 16),

          // 5) Payment method
          _buildDisabledWrapper(
            enabled: _isEnabled,
            child: _buildTextField('Payment method',
                const Key('paymentMethodField'), _paymentMethodController),
          ),

          const SizedBox(height: 32),

          _buildActionButtons(context, ref, OrderType.sell),
        ],
      ),
    );
  }

  ///
  /// BUY FORM
  ///
  Widget _buildBuyForm(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Make sure your order is below 20K sats',
              style: TextStyle(color: AppTheme.grey2)),
          const SizedBox(height: 16),

          // 1) Currency dropdown always enabled
          CurrencyComboBox(
            key: const Key('fiatCodeDropdown'),
            label: 'Fiat code',
            onSelected: (String fiatCode) {
              setState(() {
                _isEnabled = true;
              });
            },
          ),

          const SizedBox(height: 16),

          // 2) fiat amount
          _buildDisabledWrapper(
            enabled: _isEnabled,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.dark1,
                borderRadius: BorderRadius.circular(8),
              ),
              child: CurrencyTextField(
                key: const ValueKey('fiatAmountField'),
                controller: _fiatAmountController,
                label: 'Fiat amount',
                onChanged: (parsed) {
                  setState(() {
                    _minFiatAmount = parsed.$1;
                    _maxFiatAmount = parsed.$2;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 3) fixed/market toggle
          _buildDisabledWrapper(
            enabled: _isEnabled,
            child: FixedSwitch(
              initialValue: _marketRate,
              onChanged: (value) {
                setState(() {
                  _marketRate = value;
                });
              },
            ),
          ),

          const SizedBox(height: 16),

          // 4) either text for sats or a slider for premium
          if (_marketRate)
            // MARKET: Show only premium slider
            _buildDisabledWrapper(
              enabled: _isEnabled,
              child: _buildPremiumSlider(),
            )
          else
            // FIXED: Show Sats amount + LN Invoice fields
            Column(
              children: [
                _buildDisabledWrapper(
                  enabled: _isEnabled,
                  child: _buildTextField('Sats amount',
                      const Key('satsAmountField'), _satsAmountController,
                      suffix: Icon(BitcoinIcons.satoshi_v1_outline).icon),
                ),
                const SizedBox(height: 16),
              ],
            ),
          _buildDisabledWrapper(
            enabled: _isEnabled,
            child: _buildTextField(
              'Lightning Address or Lightning Invoice without an amount',
              const Key('lightningInvoiceField'),
              _lightningInvoiceController,
              nullable: true,
            ),
          ),
          const SizedBox(height: 16),
          // 6) Payment method
          _buildDisabledWrapper(
            enabled: _isEnabled,
            child: _buildTextField('Payment method',
                const Key('paymentMethodField'), _paymentMethodController),
          ),

          const SizedBox(height: 32),

          _buildActionButtons(context, ref, OrderType.buy),
        ],
      ),
    );
  }

  ///
  /// REUSABLE TEXT FIELD
  ///
  Widget _buildTextField(
      String label, Key key, TextEditingController controller,
      {bool nullable = false, IconData? suffix}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.dark1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextFormField(
        key: key,
        controller: controller,
        style: const TextStyle(color: AppTheme.cream1),
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: const TextStyle(color: AppTheme.grey2),
          suffixIcon:
              suffix != null ? Icon(suffix, color: AppTheme.grey2) : null,
        ),
        validator: nullable
            ? null
            : (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a value';
                }
                return null;
              },
      ),
    );
  }

  ///
  /// DISABLED WRAPPER
  ///
  /// If [enabled] is false, we show a grey overlay to indicate
  /// it's disabled and the child can't be interacted with.
  Widget _buildDisabledWrapper({required bool enabled, required Widget child}) {
    return IgnorePointer(
      ignoring: !enabled,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: enabled ? 1.0 : 0.4,
        child: child,
      ),
    );
  }

  ///
  /// PREMIUM SLIDER for -10..10
  ///
  Widget _buildPremiumSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Premium (%)', style: TextStyle(color: AppTheme.cream1)),
        Slider(
          key: const Key('premiumSlider'),
          value: _premiumValue,
          min: -10,
          max: 10,
          divisions: 20,
          label: _premiumValue.toStringAsFixed(1),
          onChanged: (val) {
            setState(() {
              _premiumValue = val;
            });
          },
        ),
      ],
    );
  }

  ///
  /// ACTION BUTTONS
  ///
  Widget _buildActionButtons(
      BuildContext context, WidgetRef ref, OrderType orderType) {
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

  ///
  /// SUBMIT ORDER
  ///
  void _submitOrder(BuildContext context, WidgetRef ref, OrderType orderType) {
    final selectedFiatCode = ref.read(selectedFiatCodeProvider);

    if (_formKey.currentState?.validate() ?? false) {
      // Generate a unique temporary ID for this new order
      final uuid = Uuid();
      final tempOrderId = uuid.v4();
      final notifier = ref.read(addOrderNotifierProvider(tempOrderId).notifier);

      final fiatAmount = _maxFiatAmount != null ? 0 : _minFiatAmount;
      final minAmount = _maxFiatAmount != null ? _minFiatAmount : null;
      final maxAmount = _maxFiatAmount;

      final satsAmount = int.tryParse(_satsAmountController.text) ?? 0;
      final paymentMethod = _paymentMethodController.text;

      final buyerInvoice = _lightningInvoiceController.text.isEmpty
          ? null
          : _lightningInvoiceController.text;

      final order = Order(
        kind: orderType,
        fiatCode: selectedFiatCode!,
        fiatAmount: fiatAmount!,
        minAmount: minAmount,
        maxAmount: maxAmount,
        paymentMethod: paymentMethod,
        amount: _marketRate ? 0 : satsAmount,
        premium: _marketRate ? _premiumValue.toInt() : 0,
        buyerInvoice: buyerInvoice,
      );

      notifier.submitOrder(order);
    }
  }
}
