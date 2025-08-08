import 'package:flutter/material.dart';

/// Warning icon widget for dispute list items
class DisputeIcon extends StatelessWidget {
  const DisputeIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Icon(
        Icons.warning_amber,
        color: Colors.amber,
        size: 32,
      ),
    );
  }
}
