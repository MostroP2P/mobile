import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';

class PrivacySwitch extends StatefulWidget {
  final bool initialValue;
  final ValueChanged<bool> onChanged;

  const PrivacySwitch({
    super.key,
    this.initialValue = false,
    required this.onChanged,
  });

  @override
  State<PrivacySwitch> createState() => _PrivacySwitchState();
}

class _PrivacySwitchState extends State<PrivacySwitch> {
  late bool _isFullPrivacy;

  @override
  void initState() {
    super.initState();
    _isFullPrivacy = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HeroIcon(
          _isFullPrivacy ? HeroIcons.eyeSlash : HeroIcons.eye,
          style: HeroIconStyle.outline,
          color: AppTheme.cream1,
          size: 24,
        ),
        const SizedBox(width: 8),
        // The Switch control.
        Switch(
          value: _isFullPrivacy,
          onChanged: (value) {
            setState(() {
              _isFullPrivacy = value;
            });
            widget.onChanged(value);
          },
          activeColor: AppTheme.mostroGreen,
          inactiveThumbColor: Colors.grey,
        ),
        const SizedBox(width: 8),
        // A text label that changes based on the switch value.
        Text(
          _isFullPrivacy ? 'Full Privacy' : 'Normal Privacy',
          style: const TextStyle(color: AppTheme.cream1),
        ),
      ],
    );
  }
}
