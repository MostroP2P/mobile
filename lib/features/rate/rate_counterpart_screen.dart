import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'star_rating.dart';

/// Screen that allows users to rate their counterpart after completing an order.
/// Takes an [orderId] parameter to identify which order the rating is for.
class RateCounterpartScreen extends ConsumerStatefulWidget {
  final String orderId;

  const RateCounterpartScreen({super.key, required this.orderId});

  @override
  ConsumerState<RateCounterpartScreen> createState() =>
      _RateCounterpartScreenState();
}

class _RateCounterpartScreenState extends ConsumerState<RateCounterpartScreen> {
  int _rating = 0;
  final _logger = Logger();

  Future<void> _submitRating() async {
    _logger.i('Rating submitted: $_rating');
    final orderNotifer =
        ref.watch(orderNotifierProvider(widget.orderId).notifier);

    await orderNotifer.submitRating(_rating);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(S.of(context)!.rateReceived)),
    );

    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.dark1,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Rate Counterpart',
            style: TextStyle(color: AppTheme.cream1)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.cream1),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                S.of(context)!.rate,
                style: TextStyle(color: AppTheme.cream1, fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              StarRating(
                initialRating: _rating,
                onRatingChanged: (rating) {
                  setState(() {
                    _rating = rating;
                  });
                },
              ),
              const SizedBox(height: 24),
              Text(
                '$_rating / 5',
                style: const TextStyle(color: AppTheme.cream1, fontSize: 18),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.mostroGreen,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: _rating > 0 ? _submitRating : null,
                child:
                    const Text('Submit Rating', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
