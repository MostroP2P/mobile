import 'package:flutter/material.dart';
import 'package:mostro_mobile/app/app_theme.dart';

class StarRating extends StatefulWidget {
  /// The initial rating (between 0 and 5).
  final int initialRating;

  /// Called when the user selects a new rating.
  final ValueChanged<int> onRatingChanged;

  const StarRating({
    super.key,
    this.initialRating = 0,
    required this.onRatingChanged,
  });

  @override
  State<StarRating> createState() => _StarRatingState();
}

class _StarRatingState extends State<StarRating> {
  late int _currentRating;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
  }

  Widget _buildStar(int index) {
    // Use a filled star if the index is less than current rating; otherwise an outlined star.
    final icon = index < _currentRating ? Icons.star : Icons.star_border;
    final color = index < _currentRating ? AppTheme.mostroGreen : AppTheme.grey2;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentRating = index + 1;
        });
        widget.onRatingChanged(_currentRating);
      },
      child: Icon(
        icon,
        color: color,
        size: 36,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) => _buildStar(index)),
    );
  }
}
