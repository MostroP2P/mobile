import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/order/widgets/action_button_config.dart';
import 'package:mostro_mobile/shared/widgets/mostro_reactive_button.dart';

// Use ButtonStyleType from mostro_reactive_button.dart

/// A unified button component for Mostro actions
///
/// This widget combines configuration from MostroButtonConfig with
/// the reactive behavior of MostroReactiveButton, creating a
/// consistent button UI across the app.
class MostroButton extends ConsumerWidget {
  final MostroButtonConfig config;
  
  const MostroButton({
    super.key,
    required this.config,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If we have an orderId and action, we can create a reactive button
    if (config.orderId != null) {
      return MostroReactiveButton(
        label: config.label,
        buttonStyle: config.buttonStyle, 
        orderId: config.orderId!,
        action: config.action,
        backgroundColor: config.color,
        onPressed: config.onPressed,
        showSuccessIndicator: config.showSuccessIndicator,
        timeout: config.timeout,
      );
    }
    
    // Otherwise create a regular button with the right style
    return _buildButton(context);
  }
  
  Widget _buildButton(BuildContext context) {
    switch (config.buttonStyle) {
      case ButtonStyleType.raised:
        return ElevatedButton(
          onPressed: config.onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: config.color,
          ),
          child: Text(config.label),
        );
        
      case ButtonStyleType.outlined:
        return OutlinedButton(
          onPressed: config.onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: config.color,
          ),
          child: Text(config.label),
        );
        
      case ButtonStyleType.text:
        return TextButton(
          onPressed: config.onPressed,
          style: TextButton.styleFrom(
            foregroundColor: config.color,
          ),
          child: Text(config.label),
        );
    }
  }
}
