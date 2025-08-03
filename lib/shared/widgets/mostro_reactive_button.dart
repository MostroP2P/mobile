import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/services/connection_manager.dart' as connection_mgr;

enum ButtonStyleType { raised, outlined, text }

/// Controller for managing MostroReactiveButton state externally
class MostroReactiveButtonController {
  _MostroReactiveButtonState? _state;
  
  void _attach(_MostroReactiveButtonState state) {
    _state = state;
  }
  
  void _detach() {
    _state = null;
  }
  
  void resetLoading() {
    _state?.resetLoading();
  }
}

class MostroReactiveButton extends ConsumerStatefulWidget {
  final String label;
  final ButtonStyleType buttonStyle;
  final VoidCallback onPressed;
  final String orderId;
  final actions.Action action;
  final Duration timeout;

  final bool showSuccessIndicator;

  final Color? backgroundColor;
  final Color? foregroundColor;
  final MostroReactiveButtonController? controller;

  const MostroReactiveButton({
    super.key,
    required this.label,
    required this.buttonStyle,
    required this.onPressed,
    required this.orderId,
    required this.action,
    this.timeout = const Duration(seconds: 5),
    this.showSuccessIndicator = false,
    this.backgroundColor,
    this.foregroundColor,
    this.controller,
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
  DateTime? _lastActionTime;
  static const Duration _throttleDuration = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void resetLoading() {
    setState(() {
      _loading = false;
      _showSuccess = false;
    });
    _timeoutTimer?.cancel();
  }

  void _startOperation() {
    // Basic throttling to prevent rapid-fire button presses
    final now = DateTime.now();
    if (_lastActionTime != null && 
        now.difference(_lastActionTime!) < _throttleDuration) {
      // Too soon since last action, ignore this press
      return;
    }
    
    _lastActionTime = now;
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
    final orderState = ref.watch(orderNotifierProvider(widget.orderId));
    final session = ref.watch(sessionProvider(widget.orderId));
    // Check connection state for connection-aware disabling
    final connectionState = ref.watch(connection_mgr.connectionManagerProvider);
    final isConnected = connectionState == connection_mgr.ConnectionState.connected;

    if (session != null) {
      final nextStates = orderState.getActions(session.role!);
      if (!nextStates.contains(widget.action)) {
        return const SizedBox.shrink();
      }
    }

    ref.listen(
      mostroMessageStreamProvider(widget.orderId),
      (_, next) {
        next.whenData(
          (msg) {
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
          },
        );
      },
    );

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
          onPressed: (_loading || !isConnected) ? null : _startOperation,
          style: (widget.backgroundColor != null || widget.foregroundColor != null)
              ? AppTheme.theme.elevatedButtonTheme.style?.copyWith(
                  backgroundColor: widget.backgroundColor != null
                      ? WidgetStateProperty.resolveWith((_) => widget.backgroundColor!)
                      : null,
                  foregroundColor: widget.foregroundColor != null
                      ? WidgetStateProperty.resolveWith((_) => widget.foregroundColor!)
                      : null,
                )
              : AppTheme.theme.elevatedButtonTheme.style,
          child: childWidget,
        );
        break;
      case ButtonStyleType.outlined:
        button = OutlinedButton(
          onPressed: (_loading || !isConnected) ? null : _startOperation,
          style: widget.backgroundColor != null
              ? AppTheme.theme.outlinedButtonTheme.style?.copyWith(
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (_) => widget.backgroundColor!,
                  ),
                )
              : AppTheme.theme.outlinedButtonTheme.style,
          child: childWidget,
        );
        break;
      case ButtonStyleType.text:
        button = TextButton(
          onPressed: (_loading || !isConnected) ? null : _startOperation,
          style: widget.backgroundColor != null
              ? AppTheme.theme.textButtonTheme.style?.copyWith(
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (_) => widget.backgroundColor!,
                  ),
                )
              : AppTheme.theme.textButtonTheme.style,
          child: childWidget,
        );
        break;
    }

    return button;
  }
}
