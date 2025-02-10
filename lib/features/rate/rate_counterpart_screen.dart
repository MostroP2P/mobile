import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/app/app_theme.dart';
import 'star_rating.dart';

class RateCounterpartScreen extends StatefulWidget {
  const RateCounterpartScreen({super.key});

  @override
  State<RateCounterpartScreen> createState() => _RateCounterpartScreenState();
}

class _RateCounterpartScreenState extends State<RateCounterpartScreen> {
  int _rating = 0;
  final _logger = Logger();

  void _submitRating() {
    // Here you would typically call a notifier/provider method to persist the rating.
    // For now, we'll simply print it and navigate back.
    _logger.i('Rating submitted: $_rating');
    // Optionally, show a confirmation SnackBar:
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rating submitted!')),
    );
    // Navigate back (or to a confirmation screen) using GoRouter.
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
              const Text(
                'How would you rate your counterpart?',
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
