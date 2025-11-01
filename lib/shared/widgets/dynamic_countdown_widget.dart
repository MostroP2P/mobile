import 'package:circular_countdown/circular_countdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/generated/l10n.dart';

/// Shared countdown widget for orders in PENDING status only
/// 
/// Displays a dynamic circular countdown timer that automatically scales between day/hour modes:
/// - >24 hours remaining: Day scale showing "14d 20h 06m" format  
/// - ≤24 hours remaining: Hour scale showing "HH:MM:SS" format
/// 
/// Uses exact timestamps from order_expires_at tag for precise calculations.
/// 
/// Note: Orders in waiting status (waitingBuyerInvoice, waitingPayment) use 
/// a different countdown system based on expirationSeconds + message timestamps.
class DynamicCountdownWidget extends ConsumerWidget {
  final DateTime expiration;
  final DateTime createdAt;

  const DynamicCountdownWidget({
    super.key,
    required this.expiration,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();

    // Handle edge case: expiration in the past
    if (expiration.isBefore(now.subtract(const Duration(hours: 1)))) {
      // If expiration is more than 1 hour in the past, likely invalid
      return const SizedBox.shrink();
    }

    // Calculate total duration and remaining time
    final totalDuration = expiration.difference(createdAt);
    
    // Early return if expiration is at or before creation time
    if (expiration.isAtSameMomentAs(createdAt) || expiration.isBefore(createdAt)) {
      return const SizedBox.shrink();
    }
    
    final Duration remainingTime = expiration.isAfter(now)
        ? expiration.difference(now)
        : const Duration();

    // Determine if we should use day scale (>24 hours remaining) or hour scale (≤24 hours)
    final remainingHours = remainingTime.inHours;
    final useDayScale = remainingHours > 24;

    if (useDayScale) {
      // DAY SCALE: Show days and hours
      final totalDays = ((totalDuration.inSeconds + 86399) ~/ 86400).clamp(1, double.infinity).toInt();
      final daysLeft = ((remainingTime.inHours / 24).floor()).clamp(0, totalDays);
      final hoursLeftInDay = remainingTime.inHours % 24;
      
      final minutesLeftInHour = remainingTime.inMinutes % 60;
      final formattedTime = '${daysLeft}d ${hoursLeftInDay}h ${minutesLeftInHour.toString().padLeft(2, '0')}m';

      return Column(
        children: [
          CircularCountdown(
            countdownTotal: totalDays,
            countdownRemaining: daysLeft,
          ),
          const SizedBox(height: 16),
          Text(S.of(context)!.timeLeftLabel(formattedTime)),
        ],
      );
    } else {
      // HOUR SCALE: Show hours, minutes, seconds (≤24 hours remaining)
      final totalHours = ((totalDuration.inSeconds + 3599) ~/ 3600).clamp(1, double.infinity).toInt();
      final hoursLeft = remainingTime.inHours.clamp(0, totalHours);
      final minutesLeft = remainingTime.inMinutes % 60;
      final secondsLeft = remainingTime.inSeconds % 60;

      final formattedTime =
          '${hoursLeft.toString().padLeft(2, '0')}:${minutesLeft.toString().padLeft(2, '0')}:${secondsLeft.toString().padLeft(2, '0')}';

      return Column(
        children: [
          CircularCountdown(
            countdownTotal: totalHours,
            countdownRemaining: hoursLeft,
          ),
          const SizedBox(height: 16),
          Text(S.of(context)!.timeLeftLabel(formattedTime)),
        ],
      );
    }
  }
}