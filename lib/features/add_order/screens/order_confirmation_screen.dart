import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/app/app_theme.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';

class OrderConfirmationScreen extends StatelessWidget {
  final String orderId;

  const OrderConfirmationScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              S.of(context).new_order('24'),
              style: TextStyle(fontSize: 18, color: AppTheme.cream1),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
