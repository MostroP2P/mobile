import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/features/order/widgets/form_section.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class AmountSection extends StatefulWidget {
  final OrderType orderType;
  final Function(int? minAmount, int? maxAmount) onAmountChanged;
  final String? Function(double)? validateSatsRange;
  final String? validationError;
  final ValueChanged<bool>? onRangeModeChanged;

  const AmountSection({
    super.key,
    required this.orderType,
    required this.onAmountChanged,
    this.validateSatsRange,
    this.validationError,
    this.onRangeModeChanged,
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

    // Listen to max amount changes to update badge display
    _maxAmountController.addListener(_onMaxAmountChanged);

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
          final wasRangeMode = _isRangeMode;
          _isRangeMode = false;
          _hasUserInteractedWithSecondField = false;
          _maxAmountController.clear();
          if (wasRangeMode) {
            widget.onRangeModeChanged?.call(false);
          }
        }
      });
    }
    _notifyAmountChanged();
  }

  void _onMaxAmountChanged() {
    final hasMax = _maxAmountController.text.isNotEmpty;
    final isEffectivelyRange = _isRangeMode && hasMax;
    // Trigger rebuild to show/hide badge when max amount content changes
    setState(() {});
    _notifyAmountChanged();
    widget.onRangeModeChanged?.call(isEffectivelyRange);
  }

  void _onMaxAmountFocusChanged() {
    if (_maxAmountFocusNode.hasFocus && !_hasUserInteractedWithSecondField) {
      setState(() {
        _isRangeMode = true;
        _hasUserInteractedWithSecondField = true;
      });
      widget.onRangeModeChanged?.call(true);
    }
  }

  void _notifyAmountChanged() {
    final minAmount = int.tryParse(_minAmountController.text);
    final maxAmount = int.tryParse(_maxAmountController.text);
    widget.onAmountChanged(minAmount, maxAmount);
  }

  String _getTitle() {
    if (_isRangeMode) {
      return widget.orderType == OrderType.buy
          ? S.of(context)!.creatingRangeOrderBuySend
          : S.of(context)!.creatingRangeOrder;
    }
    return widget.orderType == OrderType.buy
        ? S.of(context)!.enterAmountYouWantToSend
        : S.of(context)!.enterAmountYouWantToReceive;
  }

  Widget? _getTopRightWidget() {
    if (_isRangeMode && _maxAmountController.text.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.mostroGreen,
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
    // Only validate format - all error messages handled by validationError widget
    if (value != null && value.isNotEmpty && int.tryParse(value) == null) {
      return ''; // Return empty string to trigger form validation but not show message
    }
    return null;
  }

  String? _validateMaxAmount(String? value) {
    // Only validate format - all error messages handled by validationError widget
    if (value != null && value.isNotEmpty && int.tryParse(value) == null) {
      return ''; // Return empty string to trigger form validation but not show message
    }
    return null;
  }

  Widget _buildValidationMessage() {
    if (widget.validationError == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.statusError.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.statusError.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.statusError,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.validationError!,
              style: const TextStyle(
                color: AppTheme.statusError,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: _getTitle(),
      topRightWidget: _getTopRightWidget(),
      icon: const Icon(Icons.money, color: AppTheme.mostroGreen, size: 18),
      iconBackgroundColor: AppTheme.mostroGreen.withValues(alpha: 0.3),
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
                color: AppTheme.mostroGreen,
                fontSize: 12,
              ),
            ),
          ],

          // Validation message (shown inside card when there's an error)
          if (widget.validationError != null) ...[
            const SizedBox(height: 12),
            _buildValidationMessage(),
          ],
        ],
      ),
    );
  }
}
