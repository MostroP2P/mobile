import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';

class BuyerInfo extends StatelessWidget {
  final NostrEvent order;

  const BuyerInfo({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          backgroundColor: AppTheme.grey2,
          foregroundImage: AssetImage('assets/images/launcher-icon.png'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.name!,
                  style: const TextStyle(
                      color: AppTheme.cream1, fontWeight: FontWeight.bold)),
              Text(
                '${order.rating?.totalRating}/${order.rating?.maxRate} (${order.rating?.totalReviews})',
                style: const TextStyle(color: AppTheme.mostroGreen),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () {
            // Implement review logic
          },
          child: const Text('Read reviews',
              style: TextStyle(color: AppTheme.mostroGreen)),
        ),
      ],
    );
  }
}
