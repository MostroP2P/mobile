import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/utils/snack_bar_helper.dart';

class ClickableText extends StatefulWidget {
  final String leftText;
  final String clickableText;
  final String? rightText;

  const ClickableText({
    super.key,
    required this.leftText,
    required this.clickableText,
    this.rightText,
  });

  @override
  State<ClickableText> createState() => _ClickableTextState();
}

class _ClickableTextState extends State<ClickableText> {
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
    SnackBarHelper.showTopSnackBar(
      context,
      S.of(context)!.textCopiedToClipboard(widget.clickableText),
      duration: const Duration(seconds: 2),
    );
    await Clipboard.setData(ClipboardData(text: widget.clickableText));
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context)
            .style
            .copyWith(fontSize: 16, color: AppTheme.cream1),
        children: [
          TextSpan(text: '${widget.leftText} '),
          TextSpan(
            text: widget.clickableText,
            style: const TextStyle(
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
            recognizer: _tapRecognizer,
          ),
          if (widget.rightText != null) TextSpan(text: widget.rightText),
        ],
      ),
    );
  }
}
