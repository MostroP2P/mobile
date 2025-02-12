import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/app/app_theme.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/shared/widgets/custom_card.dart';

class TradesListItem extends StatelessWidget {
  final Session session;

  const TradesListItem({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: Navigate to a detail screen or hydrate the session with full order data.
      },
      child: CustomCard(
        color: AppTheme.dark1,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildSessionDetails(context),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Display the order ID (or a placeholder if not yet assigned)
        Text(
          session.orderId ?? 'No Order',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.cream1,
              ),
        ),
        // Display a formatted start time (for example, hour and minute)
        Text(
          'Time: ${session.startTime.hour.toString().padLeft(2, '0')}:${session.startTime.minute.toString().padLeft(2, '0')}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.cream1,
              ),
        ),
      ],
    );
  }

  Widget _buildSessionDetails(BuildContext context) {
    return Row(
      children: [
        // Display trade key index or other session summary info
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trade Key: ${session.keyIndex}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.cream1,
                    ),
              ),
              // You could add more session details here as needed.
            ],
          ),
        ),
        // Display a placeholder for status or payment method info
        Expanded(
          flex: 4,
          child: Row(
            children: [
              HeroIcon(
                HeroIcons.banknotes,
                style: HeroIconStyle.outline,
                color: AppTheme.cream1,
                size: 16,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Status: pending',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.grey2,
                      ),
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
