import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mostro_mobile/core/app_theme.dart';

class ClickableAmountText extends StatefulWidget {
  final String leftText;
  final String amount;
  final String rightText;

  const ClickableAmountText({
    super.key,
    required this.leftText,
    required this.amount,
    required this.rightText,
  });

  @override
  State<ClickableAmountText> createState() => _ClickableAmountTextState();
}

class _ClickableAmountTextState extends State<ClickableAmountText> {
  late TapGestureRecognizer _tapRecognizer;

  @override
  void initState() {
    super.initState();
    _tapRecognizer = TapGestureRecognizer()..onTap = _handleTap;
  }

  @override
  void dispose() {
    _tapRecognizer.dispose();
    super.dispose();
  }

  void _handleTap() async {
    await Clipboard.setData(ClipboardData(text: widget.amount));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Amount ${widget.amount} copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context)
            .style
            .copyWith(fontSize: 16, color: AppTheme.cream1),
        children: [
          TextSpan(text: widget.leftText),
          TextSpan(
            text: widget.amount,
            style: const TextStyle(
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
            recognizer: _tapRecognizer,
          ),
          TextSpan(text: widget.rightText),
        ],
      ),
    );
  }
}
