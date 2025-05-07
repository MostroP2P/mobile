import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/core/app_theme.dart';

enum ButtonStyleType { raised, outlined, text }

/// A button specially designed for reactive operations that shows loading state
/// and handles the unique event-based nature of the mostro protocol.
class MostroReactiveButton extends ConsumerStatefulWidget {
  final String label;
  final ButtonStyleType buttonStyle;
  final VoidCallback onPressed;
  final String orderId;
  final actions.Action action;
  final Duration timeout;

  final bool showSuccessIndicator;

  const MostroReactiveButton({
    super.key,
    required this.label,
    required this.buttonStyle,
    required this.onPressed,
    required this.orderId,
    required this.action,
    this.timeout = const Duration(seconds: 30),
    this.showSuccessIndicator = false,
    Color? backgroundColor,
  });

  @override
  ConsumerState<MostroReactiveButton> createState() =>
      _MostroReactiveButtonState();
}

class _MostroReactiveButtonState extends ConsumerState<MostroReactiveButton> {
  bool _loading = false;
  bool _showSuccess = false;
  Timer? _timeoutTimer;
  dynamic _lastSeenAction;

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _startOperation() {
    setState(() {
      _loading = true;
      _showSuccess = false;
    });
    widget.onPressed();
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(widget.timeout, _handleTimeout);
  }

  void _handleTimeout() {
    if (_loading) {
      setState(() {
        _loading = false;
        _showSuccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<dynamic>>(mostroMessageStreamProvider(widget.orderId),
        (prev, next) {
      next.whenData((msg) {
        if (msg == null || msg.action == _lastSeenAction) return;
        _lastSeenAction = msg.action;
        if (!_loading) return;
        if (msg.action == actions.Action.cantDo ||
            msg.action == widget.action) {
          setState(() {
            _loading = false;
            _showSuccess =
                widget.showSuccessIndicator && msg.action == widget.action;
          });
        }
      });
    });

    Widget childWidget;
    if (_loading) {
      childWidget = const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (_showSuccess) {
      childWidget = const Icon(Icons.check_circle, color: Colors.green);
    } else {
      childWidget = Text(widget.label);
    }

    Widget button;
    switch (widget.buttonStyle) {
      case ButtonStyleType.raised:
        button = ElevatedButton(
          onPressed: _loading ? null : _startOperation,
          style: AppTheme.theme.elevatedButtonTheme.style,
          child: childWidget,
        );
        break;
      case ButtonStyleType.outlined:
        button = OutlinedButton(
          onPressed: _loading ? null : _startOperation,
          style: AppTheme.theme.outlinedButtonTheme.style,
          child: childWidget,
        );
        break;
      case ButtonStyleType.text:
        button = TextButton(
          onPressed: _loading ? null : _startOperation,
          style: AppTheme.theme.textButtonTheme.style,
          child: childWidget,
        );
        break;
    }

    return button;
  }
}
