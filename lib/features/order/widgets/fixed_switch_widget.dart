import 'package:flutter/material.dart';

class FixedSwitch extends StatefulWidget {
  final bool initialValue;
  final ValueChanged<bool> onChanged;

  const FixedSwitch({
    super.key,
    this.initialValue = false,
    required this.onChanged,
  });

  @override
  State<FixedSwitch> createState() => _FixedSwitchState();
}

class _FixedSwitchState extends State<FixedSwitch> {
  late bool marketRate;

  @override
  void initState() {
    super.initState();
    marketRate = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Switch(
          key: const Key('fixedSwitch'),
          value: marketRate,
          onChanged: (bool value) {
            setState(() {
              marketRate = value;
            });
            widget.onChanged(value);
          },
        ),
        // Label after the switch
        const SizedBox(width: 8),
        Text(
          marketRate ? 'Market' : 'Fixed',
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }
}
