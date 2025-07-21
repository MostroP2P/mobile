import 'package:flutter/material.dart';
import 'package:mostro_mobile/features/order/widgets/form_section.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class LightningAddressSection extends StatelessWidget {
  final TextEditingController controller;

  const LightningAddressSection({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: S.of(context)!.lightningAddressOptional,
      icon: const Icon(Icons.bolt, color: Colors.amber, size: 18),
      iconBackgroundColor: Colors.amber.withValues(alpha: 0.3),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: S.of(context)!.enterLightningAddress,
          hintStyle: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
