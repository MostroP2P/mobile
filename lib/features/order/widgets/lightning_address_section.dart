import 'package:flutter/material.dart';
import 'package:mostro_mobile/features/order/widgets/form_section.dart';

class LightningAddressSection extends StatelessWidget {
  final TextEditingController controller;

  const LightningAddressSection({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: 'Lightning Address (optional)',
      icon: const Icon(Icons.bolt, color: Colors.amber, size: 18),
      iconBackgroundColor: Colors.amber.withValues(alpha: 0.3),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Enter lightning address',
          hintStyle: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
