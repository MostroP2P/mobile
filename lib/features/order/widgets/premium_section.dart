import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/order/widgets/form_section.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class PremiumSection extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const PremiumSection({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<PremiumSection> createState() => _PremiumSectionState();
}

class _PremiumSectionState extends State<PremiumSection> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  Timer? _debounceTimer;
  bool _isEditing = false;

  static const double _defaultMin = -10;
  static const double _defaultMax = 10;
  static const double _absoluteMin = -100;
  static const double _absoluteMax = 100;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.round().toString());
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(PremiumSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_isEditing) {
      _controller.text = widget.value.round().toString();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      setState(() => _isEditing = true);
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    } else {
      _debounceTimer?.cancel();
      _commitTextValue();
      setState(() => _isEditing = false);
    }
  }

  void _onTextChanged(String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _commitTextValue();
    });
  }

  void _commitTextValue() {
    final text = _controller.text.trim();
    if (text.isEmpty || text == '-') {
      _controller.text = widget.value.round().toString();
      return;
    }
    final parsed = int.tryParse(text);
    if (parsed == null) {
      _controller.text = widget.value.round().toString();
      return;
    }
    final clamped = parsed.clamp(_absoluteMin.toInt(), _absoluteMax.toInt());
    widget.onChanged(clamped.toDouble());
    _controller.text = clamped.toString();
  }

  double get _sliderMin => _defaultMin < widget.value ? _defaultMin : widget.value;
  double get _sliderMax => _defaultMax > widget.value ? _defaultMax : widget.value;

  int get _sliderDivisions {
    final range = _sliderMax - _sliderMin;
    return range.round().clamp(1, 200);
  }

  @override
  Widget build(BuildContext context) {
    final premiumInput = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            _focusNode.requestFocus();
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: 52,
                height: 32,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 6),
                    filled: true,
                    fillColor: _isEditing
                        ? AppTheme.purpleButton.withValues(alpha: 0.8)
                        : AppTheme.purpleButton,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: _isEditing
                          ? const BorderSide(
                              color: AppTheme.textPrimary, width: 1.5)
                          : BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                          color: AppTheme.textPrimary, width: 1.5),
                    ),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(signed: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^-?\d{0,3}')),
                  ],
                  onChanged: _onTextChanged,
                  onSubmitted: (_) {
                    _debounceTimer?.cancel();
                    _commitTextValue();
                    _focusNode.unfocus();
                  },
                ),
              ),
              if (!_isEditing)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppTheme.textPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit,
                      size: 9,
                      color: AppTheme.purpleButton,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          S.of(context)!.premiumEditHint,
          style: TextStyle(
            color: AppTheme.textSubtle,
            fontSize: 10,
          ),
        ),
      ],
    );

    final minLabel = '${_sliderMin.round()}%';
    final maxLabel = '+${_sliderMax.round()}%';

    return FormSection(
      title: S.of(context)!.premiumTitle,
      icon: premiumInput,
      iconBackgroundColor: Colors.transparent,
      infoTooltip: S.of(context)!.premiumTooltip,
      infoTitle: S.of(context)!.premiumTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppTheme.purpleButton,
              inactiveTrackColor: AppTheme.backgroundInactive,
              thumbColor: AppTheme.textPrimary,
              overlayColor: AppTheme.purpleButton.withValues(alpha: 0.2),
              trackHeight: 4,
            ),
            child: Slider(
              key: const Key('premiumSlider'),
              value: widget.value.clamp(_sliderMin, _sliderMax),
              min: _sliderMin,
              max: _sliderMax,
              divisions: _sliderDivisions,
              onChanged: (value) {
                widget.onChanged(value.roundToDouble());
                _controller.text = value.round().toString();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  minLabel,
                  style: const TextStyle(
                      color: AppTheme.statusError, fontSize: 12),
                ),
                Text(
                  maxLabel,
                  style: const TextStyle(
                      color: AppTheme.statusSuccess, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
