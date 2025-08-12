import 'package:flutter/material.dart';

/// Order ID widget for dispute list items
class DisputeOrderId extends StatelessWidget {
  final String orderId;

  const DisputeOrderId({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Text(
      orderId,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
    );
  }
}
