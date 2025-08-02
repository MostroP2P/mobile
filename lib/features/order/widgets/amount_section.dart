import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/features/order/widgets/form_section.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class AmountSection extends StatefulWidget {
  final OrderType orderType;
  final Function(int? minAmount, int? maxAmount) onAmountChanged;

  const AmountSection({
    super.key,
    required this.orderType,
    required this.onAmountChanged,
  });

  @override
  State<AmountSection> createState() => _AmountSectionState();
}

class _AmountSectionState extends State<AmountSection> {
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();
  final FocusNode _maxAmountFocusNode = FocusNode();

  bool _showSecondInput = false;
  bool _isRangeMode = false;
  bool _hasUserInteractedWithSecondField = false;

  @override
  void initState() {
    super.initState();

    // Listen to min amount changes to show/hide second input
    _minAmountController.addListener(_onMinAmountChanged);

    // Listen to focus changes on max amount field to enter range mode
    _maxAmountFocusNode.addListener(_onMaxAmountFocusChanged);
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    _maxAmountFocusNode.dispose();
    super.dispose();
  }

  void _onMinAmountChanged() {
    final hasContent = _minAmountController.text.isNotEmpty;
    if (hasContent != _showSecondInput) {
      setState(() {
        _showSecondInput = hasContent;
        if (!hasContent) {
          // Reset everything when min amount is cleared
          _isRangeMode = false;
          _hasUserInteractedWithSecondField = false;
          _maxAmountController.clear();
        }
      });
    }
    _notifyAmountChanged();
  }

  void _onMaxAmountFocusChanged() {
    if (_maxAmountFocusNode.hasFocus && !_hasUserInteractedWithSecondField) {
      setState(() {
        _isRangeMode = true;
        _hasUserInteractedWithSecondField = true;
      });
    }
  }

  void _notifyAmountChanged() {
    final minAmount = int.tryParse(_minAmountController.text);
    final maxAmount = int.tryParse(_maxAmountController.text);
    widget.onAmountChanged(minAmount, maxAmount);
  }

  String _getTitle() {
    if (_isRangeMode) {
      return S.of(context)!.creatingRangeOrder;
    }
    return S.of(context)!.enterAmountYouWantToReceive;
  }

  Widget? _getTopRightWidget() {
    if (_isRangeMode) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF8CC63F),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          S.of(context)!.rangeOrder,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    return null;
  }

  String? _validateMinAmount(String? value) {
    if (value == null || value.isEmpty) {
      return S.of(context)!.pleaseEnterAmount;
    }
    if (int.tryParse(value) == null) {
      return S.of(context)!.pleaseEnterValidAmount;
    }
    return null;
  }

  String? _validateMaxAmount(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Max amount is optional
    }
    if (int.tryParse(value) == null) {
      return S.of(context)!.pleaseEnterValidAmount;
    }

    final minAmount = int.tryParse(_minAmountController.text);
    final maxAmount = int.tryParse(value);
    if (minAmount != null && maxAmount != null && maxAmount <= minAmount) {
      return S.of(context)!.maxMustBeGreaterThanMin;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: _getTitle(),
      topRightWidget: _getTopRightWidget(),
      icon: const Icon(Icons.money, color: Color(0xFF8CC63F), size: 18),
      iconBackgroundColor: const Color(0xFF8CC63F).withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input row (min amount + optional max amount)
          Row(
            children: [
              // Min amount input
              Expanded(
                flex: _showSecondInput ? 2 : 1,
                child: TextFormField(
                  key: const Key('minAmountField'),
                  controller: _minAmountController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: S.of(context)!.enterAmountHint,
                    hintStyle: const TextStyle(color: Colors.grey),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _validateMinAmount,
                  onChanged: (_) => _notifyAmountChanged(),
                ),
              ),

              // "to" label and max amount input (shown after first digit)
              if (_showSecondInput) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    S.of(context)!.to,
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: const Key('maxAmountField'),
                    controller: _maxAmountController,
                    focusNode: _maxAmountFocusNode,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: S.of(context)!.maxAmount,
                      hintStyle: const TextStyle(color: Colors.grey),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: _validateMaxAmount,
                    onChanged: (_) => _notifyAmountChanged(),
                  ),
                ),
              ],
            ],
          ),

          // Tip text (shown when second input is visible but user hasn't tapped it)
          if (_showSecondInput && !_hasUserInteractedWithSecondField) ...[
            const SizedBox(height: 8),
            Text(
              S.of(context)!.tapSecondFieldForRange,
              style: const TextStyle(
                color: Color(0xFF8CC63F),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
