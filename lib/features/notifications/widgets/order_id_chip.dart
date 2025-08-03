import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';

class OrderIdChip extends StatelessWidget {
  final String orderId;

  const OrderIdChip({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppTheme.smallPadding,
      decoration: BoxDecoration(
        color: AppTheme.backgroundInput.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '#${_formatOrderId(orderId)}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 10,
          color: AppTheme.textInactive,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  String _formatOrderId(String orderId) {
    if (orderId.length <= 16) {
      return orderId;
    }
    return '${orderId.substring(0, 8)}...${orderId.substring(orderId.length - 5)}';
  }
}