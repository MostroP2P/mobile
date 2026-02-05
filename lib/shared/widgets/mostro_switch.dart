import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';

class MostroSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const MostroSwitch({
    super.key,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      thumbColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return AppTheme.textPrimary;
          }
          return AppTheme.textSecondary;
        },
      ),
      trackColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return AppTheme.mostroGreen;
          }
          return AppTheme.backgroundInactive;
        },
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    );
  }
}
