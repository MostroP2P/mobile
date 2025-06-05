import 'dart:ui';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/shared/widgets/mostro_reactive_button.dart';

/// Configuration for Mostro action buttons
/// 
/// This class encapsulates all the properties needed to render
/// a MostroButton and defines its appearance and behavior.
class MostroButtonConfig {
  /// Display label for the button
  final String label;
  
  /// Background color for the button
  final Color color;
  
  /// The Mostro action this button represents
  final actions.Action action;
  
  /// Callback when the button is pressed
  final VoidCallback onPressed;
  
  /// Whether to show success/failure indicator
  final bool showSuccessIndicator;
  
  /// Timeout duration for reactive buttons
  final Duration timeout;
  
  /// Optional order ID associated with this button
  final String? orderId;
  
  /// Button style (raised, outlined, text)
  final ButtonStyleType buttonStyle;
  
  const MostroButtonConfig({
    required this.label,
    required this.color,
    required this.action,
    required this.onPressed,
    this.showSuccessIndicator = true,
    this.timeout = const Duration(seconds: 30),
    this.orderId,
    this.buttonStyle = ButtonStyleType.raised,
  });
  
  /// Creates a copy of this config with specified fields replaced
  MostroButtonConfig copyWith({
    String? label,
    Color? color,
    actions.Action? action,
    VoidCallback? onPressed,
    bool? showSuccessIndicator,
    Duration? timeout,
    String? orderId,
    ButtonStyleType? buttonStyle,
  }) {
    return MostroButtonConfig(
      label: label ?? this.label,
      color: color ?? this.color,
      action: action ?? this.action,
      onPressed: onPressed ?? this.onPressed,
      showSuccessIndicator: showSuccessIndicator ?? this.showSuccessIndicator,
      timeout: timeout ?? this.timeout,
      orderId: orderId ?? this.orderId,
      buttonStyle: buttonStyle ?? this.buttonStyle,
    );
  }
}

// Using ButtonStyleType from mostro_reactive_button.dart