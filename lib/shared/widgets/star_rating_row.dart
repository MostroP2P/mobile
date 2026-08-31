import 'package:flutter/material.dart';

/// Five-star rating strip used by the order cards.
///
/// Replaces a per-card horizontal `ListView.builder(shrinkWrap: true)` —
/// a Scrollable + Viewport + Sliver just to lay out five icons.
class StarRatingRow extends StatelessWidget {
  const StarRatingRow({
    super.key,
    required this.rating,
    this.size = 14,
    this.color = Colors.amber,
  });

  final double rating;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final IconData icon;
        if (index < rating.floor()) {
          icon = Icons.star;
        } else if (index == rating.floor() && rating - rating.floor() >= 0.5) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, color: color, size: size);
      }),
    );
  }
}
