import 'package:flutter/material.dart';

/// Order ID widget for dispute list items
class DisputeOrderId extends StatelessWidget {
  final String orderId;

  const DisputeOrderId({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Text(
      orderId,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w500,
        fontSize: 14,
        fontFamily: 'monospace',
      ),
    );
  }
}
